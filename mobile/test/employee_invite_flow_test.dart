import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/auth/account_capabilities.dart';
import 'package:flowpay_mobile/core/auth/secure_storage_service.dart';
import 'package:flowpay_mobile/core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/design_system/input_fields.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_employee_repo.dart';
import 'package:flowpay_mobile/core/repositories/employee_repository.dart';
import 'package:flowpay_mobile/modules/auth/signup_screen.dart';
import 'package:flowpay_mobile/modules/auth/kyc_screen.dart';
import 'package:flowpay_mobile/modules/auth/set_pin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BmoniSdkService.initialize();
  });

  setUp(() {
    SecureStorageService.resetMemoryCacheForTesting();
  });

  group('Employee Invite-Then-Self-Onboard Flow Tests', () {
    test('DemoEmployeeRepository creates invite and links wallet to READY',
        () async {
      final repo = DemoEmployeeRepository();

      // 1. Employer creates employee record
      final inviteUrl = await repo.createEmployee(
        firstName: 'Zainab',
        lastName: 'Bello',
        email: 'zainab.bello@flowpay.ng',
        country: 'NG',
        targetCurrency: Currency.ngn,
        payrollAmount: Money.fromMajorString('3100000.00', Currency.ngn),
      );

      expect(inviteUrl, contains('/invite/token_demo_'));
      final token = inviteUrl.split('/').last;

      // 2. Fetch invite details
      final details = await repo.getInviteDetails(token);
      expect(details['firstName'], 'Zainab');
      expect(details['lastName'], 'Bello');
      expect(details['email'], 'zainab.bello@flowpay.ng');
      expect(details['country'], 'NG');

      // Verify employee record initially has INVITED status
      final employeeId = details['employeeId'] as String;
      final empInitial = await repo.getEmployeeById(employeeId);
      expect(empInitial.status, EmployeeLifecycleStages.invited);
      expect(empInitial.walletAddress, isNull);

      // 3. Employee self-onboards on own device, generates hardware keypair
      const employeeDeviceWallet = '0x1234567890abcdef1234567890abcdef12345678';
      const employeeBmoniUserId = 'usr_bmoni_zainab_device';

      final linkResult = await repo.linkEmployeeWallet(
        employeeId: employeeId,
        inviteToken: token,
        bmoniUserId: employeeBmoniUserId,
        walletAddress: employeeDeviceWallet,
      );

      expect(linkResult['status'], 'READY');
      expect(linkResult['walletAddress'], employeeDeviceWallet);

      // 4. Employee record in roster is now READY and ready for payroll!
      final empUpdated = await repo.getEmployeeById(employeeId);
      expect(empUpdated.status, EmployeeLifecycleStages.ready);
      expect(empUpdated.walletAddress, employeeDeviceWallet);
      expect(empUpdated.walletStatus, 'ACTIVE');
      expect(empUpdated.isReady, isTrue);
    });

    testWidgets(
        'SignupScreen resolves invite token and pre-fills employee details',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(
              employeeInviteToken: 'token_demo_test_invite',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify remote employee invite banner is visible
      expect(find.text('Remote Employee Invitation'), findsOneWidget);
      expect(
        find.text(
            'Pre-filled from employer invite. After PIN setup, your hardware wallet will link to corporate payroll.'),
        findsOneWidget,
      );

      // Verify pre-filled form fields
      expect(find.widgetWithText(FlowPayTextField, 'Full Legal Name'),
          findsOneWidget);
      final nameField = find.descendant(
        of: find.widgetWithText(FlowPayTextField, 'Full Legal Name'),
        matching: find.byType(TextField),
      );
      expect((tester.widget(nameField) as TextField).controller?.text,
          'Amara Okonkwo');

      final emailField = find.descendant(
        of: find.widgetWithText(FlowPayTextField, 'Personal Email'),
        matching: find.byType(TextField),
      );
      expect((tester.widget(emailField) as TextField).controller?.text,
          'amara.okonkwo@flowpay.ng');
    });

    testWidgets('Invite parameters pass through KYC to SetPinScreen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = UserProfile(
        userId: 'usr_personal_amara',
        fullName: 'Amara Okonkwo',
        email: 'amara.okonkwo@flowpay.ng',
        accountType: AccountType.personal,
        country: 'NG',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycScreen(
              userProfile: profile,
              employeeInviteToken: 'token_demo_test_invite',
              employeeId: 'emp_test_amara',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter National ID (BVN)
      final idField = find.descendant(
        of: find.widgetWithText(
            FlowPayTextField, 'Bank Verification Number (BVN) / NIN'),
        matching: find.byType(TextField),
      );
      await tester.enterText(idField, '22233344455');
      await tester.pumpAndSettle();

      // Run facial liveness scan
      await tester.tap(find.text('Start Liveness Scan'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Complete KYC
      await tester.tap(find.text('Complete Identity Verification'));
      await tester.pumpAndSettle();

      // Verify navigated to SetPinScreen with invite parameters attached
      expect(find.byType(SetPinScreen), findsOneWidget);
      final setPin = tester.widget<SetPinScreen>(find.byType(SetPinScreen));
      expect(setPin.employeeInviteToken, 'token_demo_test_invite');
      expect(setPin.employeeId, 'emp_test_amara');
    });
  });
}

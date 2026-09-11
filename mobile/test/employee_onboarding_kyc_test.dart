import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/auth/secure_storage_service.dart';
import 'package:flowpay_mobile/core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/repositories/employee_repository.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/modules/auth/components/live_face_scanner.dart';
import 'package:flowpay_mobile/modules/business/employee_onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BmoniSdkService.initialize();
  });

  setUp(() {
    SecureStorageService.resetMemoryCacheForTesting();
    SecureStorageService.isTestEnv = true;
  });

  final ngEmployee = EmployeeModel(
    id: 'emp_ng_test_01',
    bmoniUserId: 'usr_ng_test_01',
    firstName: 'Zainab',
    lastName: 'Bello',
    email: 'zainab@flowpay.ng',
    phoneNumber: '+2348011223344',
    country: 'NG',
    countryName: 'Nigeria',
    targetCurrency: Currency.ngn,
    status: EmployeeLifecycleStages.kycPending,
    payrollAmount: Money.fromMajorString('3500000.00', Currency.ngn),
  );

  final mxEmployee = EmployeeModel(
    id: 'emp_mx_test_01',
    bmoniUserId: 'usr_mx_test_01',
    firstName: 'Mateo',
    lastName: 'Hernandez',
    email: 'mateo@flowpay.mx',
    phoneNumber: '+525512345678',
    country: 'MX',
    countryName: 'Mexico',
    targetCurrency: Currency.mxn,
    status: EmployeeLifecycleStages.kycPending,
    payrollAmount: Money.fromMajorString('45000.00', Currency.mxn),
  );

  group('Employee Onboarding KYC Screen Tests', () {
    testWidgets('Nigeria Stage 3 renders BVN with 11-digit indicator and DOB picker',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EmployeeOnboardingScreen(
              appState: appState,
              employee: ngEmployee,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Step 3 tab
      await tester.tap(find.text('Step 3\nVerify'));
      await tester.pumpAndSettle();

      // Verify Stage 3 Nigeria UI
      expect(find.text('Step 3: Identity Verification (Nigeria)'), findsOneWidget);
      expect(find.text('Bank Verification Number (BVN)'), findsOneWidget);
      expect(find.text('National Identification Number (NIN)'), findsOneWidget);
      expect(find.text('Date of Birth (YYYY-MM-DD)'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

      // Verify 11-digit BVN helper indicator
      expect(find.text('✓ 11-digit BVN verified format'), findsOneWidget);
      expect(
        find.text('Biometric selfie is not required for Nigeria verification per BMONI specifications.'),
        findsOneWidget,
      );
    });

    testWidgets('Mexico Stage 3 renders CURP, RFC, DOB picker, and LiveFaceScanner',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EmployeeOnboardingScreen(
              appState: appState,
              employee: mxEmployee,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Step 3 tab
      await tester.tap(find.text('Step 3\nVerify'));
      await tester.pumpAndSettle();

      // Verify Stage 3 Mexico UI
      expect(find.text('Step 3: Identity Verification (Mexico)'), findsOneWidget);
      expect(find.text('CURP (18 characters)'), findsOneWidget);
      expect(find.text('RFC (12-13 characters)'), findsOneWidget);
      expect(find.text('Date of Birth (YYYY-MM-DD)'), findsOneWidget);
      expect(find.byType(LiveFaceScanner), findsOneWidget);
      expect(find.text('Start Liveness Scan'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/auth/account_capabilities.dart';
import 'package:flowpay_mobile/core/auth/secure_storage_service.dart';
import 'package:flowpay_mobile/core/design_system/input_fields.dart';
import 'package:flowpay_mobile/modules/auth/components/live_face_scanner.dart';
import 'package:flowpay_mobile/modules/auth/kyc_screen.dart';
import 'package:flowpay_mobile/modules/auth/set_pin_screen.dart';

Future<void> enterField(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find.widgetWithText(FlowPayTextField, label),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, value);
}

void main() {
  setUp(() {
    SecureStorageService.resetMemoryCacheForTesting();
    SecureStorageService.isTestEnv = true;
  });

  final testProfile = UserProfile(
    userId: 'usr_test_kyc_01',
    fullName: 'Amara Test User',
    email: 'amara@flowpay.finance',
    accountType: AccountType.personal,
    country: 'NG',
    phone: '+2348011223344',
    createdAt: DateTime.now(),
  );

  group('FlowPay KYC Validation & Live Camera Tests', () {
    testWidgets('Renders KycScreen with BVN input, calendar picker icon, and LiveFaceScanner',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycScreen(userProfile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Identity Verification'), findsOneWidget);
      expect(find.text('Bank Verification Number (BVN) / NIN'), findsOneWidget);
      expect(find.text('Date of Birth (YYYY-MM-DD)'), findsOneWidget);
      expect(find.text('Residential Address'), findsOneWidget);
      expect(find.byType(LiveFaceScanner), findsOneWidget);
      expect(find.text('Start Liveness Scan'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    });

    testWidgets('Validates 11-digit BVN strictly (blocks < 11 digits and 00000000000)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycScreen(userProfile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 8 digits (too short)
      await enterField(tester, 'Bank Verification Number (BVN) / NIN', '12345678');
      await enterField(tester, 'Date of Birth (YYYY-MM-DD)', '1995-05-15');
      await enterField(tester, 'Residential Address', '15 Marina Street, Lagos');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Set PIN'));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('BVN must be exactly 11 digits (entered 8/11)'), findsOneWidget);

      // Enter all zeros (invalid dummy sequence)
      await enterField(tester, 'Bank Verification Number (BVN) / NIN', '00000000000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Set PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid 11-digit BVN'), findsOneWidget);

      // Enter valid 11-digit BVN
      await enterField(tester, 'Bank Verification Number (BVN) / NIN', '22222222222');
      await tester.pumpAndSettle();

      // Expect verified format pill
      expect(find.text('✓ 11-digit BVN verified format'), findsOneWidget);
    });

    testWidgets('Validates Date of Birth format and rejects underage (< 18 years old)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycScreen(userProfile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid BVN
      await enterField(tester, 'Bank Verification Number (BVN) / NIN', '22222222222');

      // Enter underage birth date (e.g. 10 years ago)
      final now = DateTime.now();
      final underageYear = now.year - 10;
      await enterField(tester, 'Date of Birth (YYYY-MM-DD)', '$underageYear-01-01');
      await enterField(tester, 'Residential Address', '15 Marina Street, Lagos');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Set PIN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You must be at least 18 years of age'), findsOneWidget);

      // Enter valid adult birth date
      await enterField(tester, 'Date of Birth (YYYY-MM-DD)', '1995-04-12');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Set PIN'));
      await tester.pumpAndSettle();

      // Now date error is gone, but face scan is required
      expect(find.textContaining('You must be at least 18 years of age'), findsNothing);
      expect(find.text('Please perform the facial liveness verification to proceed.'), findsOneWidget);
    });

    testWidgets('LiveFaceScanner verification completes and allows navigation to SetPinScreen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycScreen(userProfile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill valid KYC form
      await enterField(tester, 'Bank Verification Number (BVN) / NIN', '99999999999');
      await enterField(tester, 'Date of Birth (YYYY-MM-DD)', '1992-06-20');
      await enterField(tester, 'Residential Address', '100 Admiralty Way, Lekki');
      await tester.pumpAndSettle();

      // Perform Face Scan
      await tester.tap(find.text('Start Liveness Scan'));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Facial Biometrics Verified ✅'), findsOneWidget);
      expect(find.text('Verified Live Biometrics'), findsOneWidget);

      // Submit KYC and advance to Set PIN
      await tester.tap(find.text('Verify & Set PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(find.text('Set Your 6-Digit PIN'), findsOneWidget);
    });
  });
}

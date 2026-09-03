import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/app.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/modules/auth/signup_screen.dart';
import 'package:flowpay_mobile/modules/auth/kyc_screen.dart';
import 'package:flowpay_mobile/modules/auth/set_pin_screen.dart';
import 'package:flowpay_mobile/modules/auth/login_screen.dart';

void main() {
  group('Signup, KYC and Account Separation Tests', () {
    testWidgets('Opens SignupScreen from lock screen and renders form controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      // App starts locked behind AppAuthGate
      expect(find.text('FlowPay is Locked'), findsOneWidget);
      expect(find.text('Create New Account / Sign Up'), findsOneWidget);

      // Tap Create New Account
      await tester.tap(find.text('Create New Account / Sign Up'));
      await tester.pumpAndSettle();

      // Verify on SignupScreen
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Proceed to Identity Verification'), findsOneWidget);
    });

    testWidgets('Personal signup autofill and navigation to KYC screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Account / Sign Up'));
      await tester.pumpAndSettle();

      // Tap Quick Personal Demo Autofill (Bunch Dillon)
      await tester.tap(find.text('👤 Personal (Bunch)'));
      await tester.pumpAndSettle();

      expect(find.text('Bunch Dillon'), findsOneWidget);
      expect(find.text('bunch.dillon@remote.africa'), findsOneWidget);

      // Proceed to Identity Verification
      await tester.tap(find.text('Proceed to Identity Verification'));
      await tester.pumpAndSettle();

      // Verify on KycScreen in Personal mode
      expect(find.byType(KycScreen), findsOneWidget);
      expect(find.text('Identity Verification'), findsOneWidget);
      expect(find.text('Step 1: Government Identity'), findsOneWidget);
      expect(find.text('Step 2: Facial Biometric Liveness'), findsOneWidget);
      expect(find.text('Start Liveness Scan'), findsOneWidget);
    });

    testWidgets('Completing Personal KYC lands strictly in Personal Shell with Personal-only header',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Account / Sign Up'));
      await tester.pumpAndSettle();

      // Autofill personal
      await tester.tap(find.text('👤 Personal (Bunch)'));
      await tester.pumpAndSettle();

      // Proceed to KYC
      await tester.tap(find.text('Proceed to Identity Verification'));
      await tester.pumpAndSettle();

      // Run facial scan
      await tester.tap(find.text('Start Liveness Scan'));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Facial Biometrics Verified ✅'), findsOneWidget);

      // Complete Verification & Proceed to Set PIN
      await tester.tap(find.text('Complete KYC & Set PIN'));
      await tester.pumpAndSettle();

      // Verify on SetPinScreen
      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(find.text('Set Your 6-Digit PIN'), findsOneWidget);

      // Enter 6 digits
      for (var d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Confirmation stage
      expect(find.text('Confirm Your 6-Digit PIN'), findsOneWidget);
      for (var d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Should now be in PersonalShell with Personal-only title badge
      expect(find.text('Personal Account'), findsWidgets);
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('Overview')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Wallets')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Missions')), findsOneWidget);
    });

    testWidgets('Business signup autofill, corporate KYB, Set PIN, and strict Business Shell landing',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Account / Sign Up'));
      await tester.pumpAndSettle();

      // Tap Quick Business Demo Autofill (FlowPay Global Ltd)
      await tester.tap(find.text('💼 Business (FlowPay)'));
      await tester.pumpAndSettle();

      expect(find.text('FlowPay Technologies Ltd'), findsOneWidget);
      expect(find.text('Founder & CEO'), findsOneWidget);

      // Proceed to Corporate KYB
      await tester.tap(find.text('Proceed to Identity Verification'));
      await tester.pumpAndSettle();

      // Verify on KycScreen in Business mode
      expect(find.byType(KycScreen), findsOneWidget);
      expect(find.text('Corporate KYB Compliance'), findsOneWidget);
      expect(find.text('Step 1: Corporate Legal Entity'), findsOneWidget);
      expect(find.text('Step 2: Authorized Signatory Verification'), findsOneWidget);
      expect(find.text('Disbursement Rails Activated'), findsOneWidget);

      // Submit Corporate Verification & proceed to Set PIN
      await tester.tap(find.text('Activate Rails & Set PIN'));
      await tester.pumpAndSettle();

      // Verify on SetPinScreen
      expect(find.byType(SetPinScreen), findsOneWidget);
      for (var d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Confirm PIN
      for (var d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Should now be in BusinessShell with Business-only company title badge
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Payroll'), findsOneWidget);
      expect(find.text('Audit'), findsOneWidget);
    });

    testWidgets('Opens LoginScreen and logs in via email and PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      // On Lock Screen, tap Log In to Existing Account
      expect(find.text('Log In to Existing Account'), findsOneWidget);
      await tester.tap(find.text('Log In to Existing Account'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Log In to FlowPay'), findsOneWidget);

      // Quick autofill personal
      await tester.tap(find.text('👤 Personal'));
      await tester.pumpAndSettle();

      // Tap Log In
      await tester.tap(find.text('Log In'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Lands in Personal shell
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Wallets'), findsWidgets);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/core/theme/theme.dart';
import 'package:flowpay_mobile/core/wallet/components/wallet_pin_auth_sheet.dart';
import 'package:flowpay_mobile/modules/personal/personal_security_screen.dart';
import 'package:flowpay_mobile/modules/personal/wallet_provisioning_screen.dart';

void main() {
  group('FlowPay Personal Security Tests', () {
    late AppState appState;

    setUp(() async {
      appState = AppState();
      await BmoniSdkService.initWallet();
      await BmoniSdkService.setPin('123456');
    });

    testWidgets('Renders all 3 core security sections and required indicators',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FlowPayTheme.dark(),
            home: Scaffold(
              body: PersonalSecurityScreen(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hero Trust Banner
      expect(find.text('Your account is secured'), findsOneWidget);
      expect(find.text('Your funds are protected on this device'),
          findsOneWidget);
      expect(find.text('SECURE'), findsOneWidget);
      expect(find.text('BANK-GRADE ENCRYPTION'), findsOneWidget);

      // 2. Section 1: Wallet Security
      expect(find.text('Secure wallet'), findsOneWidget);
      expect(find.text('READY'),
          findsWidgets); // Shows whether wallet is initialized
      expect(find.text('Account address'), findsOneWidget);
      expect(find.textContaining('0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19'),
          findsOneWidget);
      expect(find.text('Manage your secure wallet'), findsOneWidget);

      // 3. Section 2: Signing Security
      expect(find.text('PIN & biometrics'), findsOneWidget);
      expect(find.text('READY'),
          findsWidgets); // Shows whether device signing is available
      expect(find.text('Payment confirmation'), findsOneWidget);
      expect(find.text('Security PIN'),
          findsOneWidget); // Shows whether PIN protection is enabled
      expect(find.text('ENABLED'), findsWidgets);
      expect(find.text('Face ID & Fingerprint'), findsOneWidget);
      expect(find.text('Test PIN'), findsOneWidget);

      // 4. Section 3: Approval Rules
      expect(find.text('Approval settings'), findsOneWidget);
      // Explains: "Financial actions require your approval."
      expect(find.text('"Financial actions require your approval."'),
          findsOneWidget);
      expect(find.textContaining('FlowPay AI only makes suggestions'),
          findsOneWidget);

      // The 4 Invariants of FlowPay Financial Safety
      expect(find.text('How FlowPay keeps your money safe'),
          findsOneWidget);
      expect(find.text('Understanding your request'), findsOneWidget);
      expect(find.text('Checking your plan'), findsOneWidget);
      expect(find.text('You review everything'), findsOneWidget);
      expect(find.text('You confirm with your PIN'), findsOneWidget);

      // Policy matrix
      expect(find.text('Sending money'), findsOneWidget);
      expect(find.text('Currency exchanges'), findsOneWidget);
      expect(find.text('Automatic rules'), findsOneWidget);
      expect(find.text('Card actions'), findsOneWidget);

      // Honest disclosure
      expect(
          find.textContaining('FlowPay keeps your money secure on your device'),
          findsOneWidget);
    });

    testWidgets(
        'Tapping "Manage your secure wallet" navigates to WalletProvisioningScreen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FlowPayTheme.dark(),
            home: Scaffold(
              body: PersonalSecurityScreen(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage your secure wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletProvisioningScreen), findsOneWidget);
    });

    testWidgets('Tapping "Test PIN" opens PIN authorization sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FlowPayTheme.dark(),
            home: Scaffold(
              body: PersonalSecurityScreen(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletPinAuthSheet), findsOneWidget);
      expect(find.text('Test your PIN'), findsOneWidget);
      expect(find.text('Your FlowPay wallet is secured on this device.'),
          findsOneWidget);
    });
  });
}

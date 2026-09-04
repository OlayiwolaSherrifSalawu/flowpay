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

    testWidgets('Renders all 3 core security sections and required indicators', (tester) async {
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
      expect(find.text('B-Key Hardware Enclave Active'), findsOneWidget);
      expect(find.text('On-Device Self-Custody • Zero Remote Private Keys'), findsOneWidget);
      expect(find.text('SECURE'), findsOneWidget);
      expect(find.text('SECP256K1 HARDWARE'), findsOneWidget);
      expect(find.text('ZERO AI CUSTODY'), findsOneWidget);

      // 2. Section 1: Wallet Security
      expect(find.text('1. Wallet Security'), findsOneWidget);
      expect(find.text('INITIALIZED'), findsWidgets); // Shows whether wallet is initialized
      expect(find.text('On-Device EVM Public Address'), findsOneWidget);
      expect(find.textContaining('0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19'), findsOneWidget);
      expect(find.text('Manage On-Device B-Key Wallet'), findsOneWidget);

      // 3. Section 2: Signing Security
      expect(find.text('2. Signing Security'), findsOneWidget);
      expect(find.text('AVAILABLE & ACTIVE'), findsOneWidget); // Shows whether device signing is available
      expect(find.text('Device Hardware Signer'), findsOneWidget);
      expect(find.text('6-Digit Security PIN Protection'), findsOneWidget); // Shows whether PIN protection is enabled
      expect(find.text('CONFIGURED'), findsWidgets);
      expect(find.text('Biometric App Gate'), findsOneWidget);
      expect(find.text('Test Signer'), findsOneWidget);

      // 4. Section 3: Approval Rules
      expect(find.text('3. Approval Rules'), findsOneWidget);
      expect(find.text('ZERO AI EXECUTION'), findsOneWidget);
      // Explains: "Financial actions require your approval."
      expect(find.text('"Financial actions require your approval."'), findsOneWidget);
      expect(find.textContaining('AI models in FlowPay are strictly advisory'), findsOneWidget);

      // The 4 Invariants of FlowPay Financial Safety
      expect(find.text('The 4 Invariants of FlowPay Financial Safety'), findsOneWidget);
      expect(find.text('Structured Intent Interpretation'), findsOneWidget);
      expect(find.text('Deterministic Rule Validation'), findsOneWidget);
      expect(find.text('Mandatory Human Preview'), findsOneWidget);
      expect(find.text('On-Device B-Key Hardware Signature'), findsOneWidget);

      // Policy matrix
      expect(find.text('Outbound Multi-Currency Transfers'), findsOneWidget);
      expect(find.text('Instant FX Conversions'), findsOneWidget);
      expect(find.text('Money Mission Allocations'), findsOneWidget);
      expect(find.text('Card Limit & Freeze Actions'), findsOneWidget);

      // Honest disclosure (do not claim unsupported security features)
      expect(find.textContaining('Genuine Security Standard'), findsOneWidget);
      expect(find.textContaining('FlowPay does not claim unsupported cloud MPC'), findsOneWidget);
    });

    testWidgets('Tapping "Manage On-Device B-Key Wallet" navigates to WalletProvisioningScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
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

      await tester.tap(find.text('Manage On-Device B-Key Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletProvisioningScreen), findsOneWidget);
    });

    testWidgets('Tapping "Test Signer" opens PIN authorization sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
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

      await tester.tap(find.text('Test Signer'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletPinAuthSheet), findsOneWidget);
      expect(find.text('Test Device Signer'), findsOneWidget);
      expect(find.text('Your FlowPay wallet is secured on this device.'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowpay_mobile/core/wallet/wallet_service.dart';
import 'package:flowpay_mobile/core/wallet/components/wallet_pin_auth_sheet.dart';
import 'package:flowpay_mobile/modules/personal/wallet_provisioning_screen.dart';

/// In-memory mock wallet service for UI widget tests.
class _MockWalletService implements WalletService {
  bool _hasWallet = false;
  String? _address;
  String? _pin;

  @override
  Future<void> initialize({int pinLength = 6, bool requirePin = true}) async {}

  @override
  Future<bool> hasWallet() async => _hasWallet;

  @override
  Future<String> createWallet() async {
    _address = '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19';
    _hasWallet = true;
    return _address!;
  }

  @override
  Future<String?> getWalletAddress() async => _address;

  @override
  Future<void> deleteWallet({String? pin}) async {
    _address = null;
    _hasWallet = false;
  }

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<bool> matchPin(String pin) async => _pin == pin;

  @override
  Future<void> changePin(
      {required String currentPin, required String newPin}) async {
    _pin = newPin;
  }

  @override
  Future<void> removePin(String currentPin) async => _pin = null;
}

/// Builds a test harness with overridden WalletService.
Widget _buildTestApp({_MockWalletService? mockService}) {
  final service = mockService ?? _MockWalletService();
  return ProviderScope(
    overrides: [walletServiceProvider.overrideWithValue(service)],
    child: const MaterialApp(home: WalletProvisioningScreen()),
  );
}

/// Pumps enough frames to settle synchronous + fast async state without hanging.
Future<void> pumpSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Scrolls within the [WalletProvisioningScreen]'s primary [ListView] to make
/// [finder] visible. The primary Scrollable is identified by being a ListView's
/// direct Scrollable — we pick the first one found.
Future<void> scrollToVisible(WidgetTester tester, Finder finder) async {
  final scrollables = find.byType(Scrollable);
  // Use the first Scrollable (the ListView body) since there should only be
  // one in the WalletProvisioningScreen's body at any time.
  final primaryScrollable = scrollables.first;
  await tester.scrollUntilVisible(finder, 200, scrollable: primaryScrollable);
}

void main() {
  // ---------------------------------------------------------------------------
  // WALLET PROVISIONING SCREEN — NO WALLET STATE
  // ---------------------------------------------------------------------------
  group('WalletProvisioningScreen — No Wallet State', () {
    testWidgets('Displays setup headline and trust copy', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await pumpSettled(tester);

      expect(find.text('On-Device B-Key Wallet'), findsOneWidget);
      expect(find.text('Set Up Your Secure FlowPay Wallet'), findsOneWidget);
      expect(
        find.text('Your FlowPay wallet is secured on this device.'),
        findsOneWidget,
      );
    });

    testWidgets('Displays all 3 benefit cards', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await pumpSettled(tester);

      expect(find.text('Protected by Device Hardware'), findsOneWidget);
      expect(find.text('Instant Multi-Currency Rails'), findsOneWidget);
      expect(find.text('6-Digit Transaction PIN'), findsOneWidget);
    });

    testWidgets('Create wallet CTA button is present', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await pumpSettled(tester);

      await scrollToVisible(tester, find.text('Create My Secure Wallet'));
      expect(find.text('Create My Secure Wallet'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // WALLET PROVISIONING SCREEN — WALLET CREATION FLOW
  // ---------------------------------------------------------------------------
  group('WalletProvisioningScreen — Wallet Creation', () {
    testWidgets('Tapping CTA transitions to ready state', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await pumpSettled(tester);

      await scrollToVisible(tester, find.text('Create My Secure Wallet'));
      await tester.tap(find.text('Create My Secure Wallet'));
      await pumpSettled(tester);

      expect(find.text('FlowPay Wallet Active'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // WALLET PROVISIONING SCREEN — READY STATE
  // ---------------------------------------------------------------------------
  group('WalletProvisioningScreen — Ready State', () {
    testWidgets('Displays status banner and READY badge', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      expect(find.text('FlowPay Wallet Active'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
    });

    testWidgets('Displays wallet address', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      expect(find.text('On-Device Wallet Address'), findsOneWidget);
      expect(
        find.text('0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19'),
        findsOneWidget,
      );
    });

    testWidgets('Displays hardware security specs', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      await scrollToVisible(tester, find.text('Hardware Security Specs'));
      expect(find.text('Hardware Security Specs'), findsOneWidget);
      expect(find.text('secp256k1 (EIP-191 / EIP-712)'), findsOneWidget);
      expect(find.text('Zero Access (Self-Custody)'), findsOneWidget);
    });

    testWidgets('Displays supported tokens', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      expect(find.text('USDB • CNGN • MEXe • CADC'), findsOneWidget);
    });

    testWidgets('Copy address button shows snackbar', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      await tester.tap(find.byTooltip('Copy Address'));
      await pumpSettled(tester);

      expect(find.text('Address copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Refresh button appears and triggers reload', (tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      expect(find.byTooltip('Refresh Status'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh Status'));
      await pumpSettled(tester);

      expect(find.text('FlowPay Wallet Active'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // WALLET PROVISIONING SCREEN — DELETION DIALOG
  // ---------------------------------------------------------------------------
  group('WalletProvisioningScreen — Wallet Deletion', () {
    /// Helper: get to the delete confirmation dialog.
    Future<void> openDeleteDialog(WidgetTester tester) async {
      final mockService = _MockWalletService();
      await mockService.createWallet();

      await tester.pumpWidget(_buildTestApp(mockService: mockService));
      await pumpSettled(tester);

      await scrollToVisible(tester, find.text('Delete Wallet From Device'));
      await tester.tap(find.text('Delete Wallet From Device'));
      await pumpSettled(tester);
    }

    testWidgets('Delete dialog shows warning copy', (tester) async {
      await openDeleteDialog(tester);

      expect(find.text('Delete On-Device Wallet?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);
    });

    testWidgets('Cancel leaves state unchanged', (tester) async {
      await openDeleteDialog(tester);

      await tester.tap(find.text('Cancel'));
      await pumpSettled(tester);

      // Still in ready state.
      expect(find.text('FlowPay Wallet Active'), findsOneWidget);
    });

    testWidgets('Confirming delete transitions to noWallet', (tester) async {
      await openDeleteDialog(tester);

      await tester.tap(find.text('Delete Permanently'));
      await pumpSettled(tester);

      expect(find.text('Set Up Your Secure FlowPay Wallet'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // FULL LIFECYCLE FLOW
  // ---------------------------------------------------------------------------
  group('WalletProvisioningScreen — Full Lifecycle', () {
    testWidgets('Create → Ready → Delete → noWallet', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await pumpSettled(tester);

      // 1. Start: No Wallet.
      expect(find.text('Set Up Your Secure FlowPay Wallet'), findsOneWidget);

      // 2. Scroll to CTA and create.
      await scrollToVisible(tester, find.text('Create My Secure Wallet'));
      await tester.tap(find.text('Create My Secure Wallet'));
      await pumpSettled(tester);

      // 3. Verify ready.
      expect(find.text('FlowPay Wallet Active'), findsOneWidget);

      // 4. Open delete dialog.
      await scrollToVisible(tester, find.text('Delete Wallet From Device'));
      await tester.tap(find.text('Delete Wallet From Device'));
      await pumpSettled(tester);

      // 5. Confirm delete.
      await tester.tap(find.text('Delete Permanently'));
      await pumpSettled(tester);

      // 6. Back to setup.
      expect(find.text('Set Up Your Secure FlowPay Wallet'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // PIN AUTH SHEET — WIDGET TESTS
  // ---------------------------------------------------------------------------
  group('WalletPinAuthSheet — PIN entry UI', () {
    testWidgets('Renders title, trust banner, keypad and cancel',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  WalletPinAuthSheet.show(
                    context: context,
                    title: 'Authorize Payment',
                    amountDisplay: '\$100.00 USDB',
                    recipient: 'john@example.com',
                    onAuthorize: (pin) async => '0xSIG',
                  );
                },
                child: const Text('Open PIN Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open PIN Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Authorize Payment'), findsOneWidget);
      expect(find.text('\$100.00 USDB'), findsOneWidget);
      expect(find.text('To: john@example.com'), findsOneWidget);
      expect(
        find.text('Your FlowPay wallet is secured on this device.'),
        findsOneWidget,
      );

      // Numeric keypad.
      for (var i = 0; i <= 9; i++) {
        expect(find.byKey(Key('pin_key_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('pin_key_backspace')), findsOneWidget);
      expect(find.byKey(const Key('wallet_pin_cancel_button')), findsOneWidget);
    });

    testWidgets('Cancel button dismisses the sheet with null result',
        (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await WalletPinAuthSheet.show(
                    context: context,
                    title: 'Test',
                    onAuthorize: (pin) async => '0xSIG',
                  );
                },
                child: const Text('Open PIN Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open PIN Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('wallet_pin_cancel_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNull);
    });

    testWidgets('Tapping digits does not crash the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  WalletPinAuthSheet.show(
                    context: context,
                    title: 'Enter PIN',
                    onAuthorize: (pin) async => '0xSIG',
                  );
                },
                child: const Text('Open PIN Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open PIN Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 3 digits.
      await tester.tap(find.byKey(const Key('pin_key_1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_2')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_3')));
      await tester.pump(const Duration(milliseconds: 50));

      // No crash — sheet still visible.
      expect(find.text('Enter PIN'), findsOneWidget);
    });
  });
}

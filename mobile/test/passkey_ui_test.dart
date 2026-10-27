import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/wallet/components/wallet_pin_auth_sheet.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';
import 'helpers/fake_passkeys.dart';

void main() {
  late FakePasskeys passkeys;
  setUp(() async {
    passkeys = FakePasskeys();
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000, passkeys: passkeys);
    await StellarKeyVault.instance.createWallet(pin: '123456');
    await StellarKeyVault.instance.markBackedUp();
    await StellarKeyVault.instance.enablePasskey(pin: '123456');
  });

  Future<String?> openSheet(WidgetTester tester) async {
    String? result = 'not-closed';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await WalletPinAuthSheet.show(
              context: context,
              title: 'Send money',
              amountDisplay: r'$25.00',
              onAuthorize: (pin) => const StellarWalletSigner().signMessage('hello', pin: pin),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('passkey wallets confirm with Face ID / passkey instead of a keypad', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await WalletPinAuthSheet.show(
              context: context,
              title: 'Send money',
              onAuthorize: (pin) => const StellarWalletSigner().signMessage('hello', pin: pin),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet_pin_passkey_button')), findsOneWidget);
    expect(find.text('1'), findsNothing, reason: 'no PIN keypad');

    // A cancelled prompt keeps the sheet open with a retry message.
    passkeys.cancelNext = true;
    await tester.tap(find.byKey(const Key('wallet_pin_passkey_button')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled. Tap to try again.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet_pin_passkey_button')));
    await tester.pumpAndSettle();
    expect(result, matches(RegExp(r'^[0-9a-f]{128}$')), reason: 'a real ed25519 signature, unlocked by the passkey');
  });

  testWidgets('PIN wallets still get the keypad', (tester) async {
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000, passkeys: FakePasskeys());
    await StellarKeyVault.instance.createWallet(pin: '123456');
    await openSheet(tester);
    expect(find.byKey(const Key('wallet_pin_passkey_button')), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

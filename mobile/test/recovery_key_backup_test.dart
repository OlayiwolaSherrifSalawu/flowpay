import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/wallet/wallet_service.dart';
import 'package:flowpay_mobile/modules/auth/recovery_key_backup_screen.dart';
import 'package:flowpay_mobile/modules/personal/components/recovery_backup_reminder.dart';
import 'helpers/test_wallet.dart';

void main() {
  group('Recovery key backup state (vault)', () {
    test('a new wallet is not backed up until the user confirms', () async {
      final vault = StellarKeyVault.instance;
      await provisionTestWallet();
      expect(await vault.isBackedUp(), isFalse);
      await vault.markBackedUp();
      expect(await vault.isBackedUp(), isTrue);
    });

    test('restoring from a recovery key counts as backed up; deleting clears it', () async {
      final source = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
      await source.createWallet(pin: testWalletPin);
      final seed = await source.exportRecoveryKey(pin: testWalletPin);

      final vault = StellarKeyVault.instance;
      await vault.importWallet(secretSeed: seed, pin: testWalletPin);
      expect(await vault.isBackedUp(), isTrue);
      await vault.deleteWallet(pin: testWalletPin);
      expect(await vault.isBackedUp(), isFalse);
    });

    test('marking a backup without a wallet fails loudly', () async {
      await expectLater(StellarKeyVault.instance.markBackedUp(), throwsA(isA<StellarVaultException>()));
    });
  });

  group('Recovery key backup screen', () {
    late String key;
    setUp(() async {
      await provisionTestWallet();
      key = await StellarKeyVault.instance.exportRecoveryKey(pin: testWalletPin);
    });

    testWidgets('key is hidden until revealed; confirming needs the right last 4 characters', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: RecoveryKeyBackupScreen(recoveryKey: key, walletService: const StellarWalletService()),
      ));
      await tester.pumpAndSettle();
      expect(find.text(key), findsNothing, reason: 'hidden until the user reveals it');

      await tester.tap(find.byKey(const Key('recovery_key_reveal')));
      await tester.pumpAndSettle();
      expect(find.text(key), findsOneWidget);

      Future<void> confirmWith(String text) async {
        await tester.enterText(find.byKey(const Key('recovery_key_confirm_field')), text);
        await tester.ensureVisible(find.byKey(const Key('recovery_key_done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('recovery_key_done')));
        await tester.pumpAndSettle();
      }

      await confirmWith(key.endsWith('ZZZZ') ? 'YYYY' : 'ZZZZ');
      expect(find.text("That doesn't match the end of your recovery key."), findsOneWidget);
      expect(await StellarKeyVault.instance.isBackedUp(), isFalse);

      await confirmWith(key.substring(key.length - 4).toLowerCase());
      expect(await StellarKeyVault.instance.isBackedUp(), isTrue);
    });

    testWidgets('dashboard reminder shows until the key is saved', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RecoveryBackupReminder())));
      await tester.pumpAndSettle();
      expect(find.text('Back up your recovery key'), findsOneWidget);

      await StellarKeyVault.instance.markBackedUp();
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RecoveryBackupReminder(key: ValueKey('again')))));
      await tester.pumpAndSettle();
      expect(find.text('Back up your recovery key'), findsNothing);
    });
  });
}

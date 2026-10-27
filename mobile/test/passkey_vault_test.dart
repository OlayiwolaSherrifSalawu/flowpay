import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/stellar/passkey/passkey_authenticator.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Behaves like a WebAuthn PRF authenticator: the secret is a function of a
/// device-held key, the credential and the salt; prompts can be cancelled.
class FakePasskeys implements PasskeyAuthenticator {
  final String deviceSecret;
  bool supported;
  bool cancelNext = false;
  int prompts = 0;
  FakePasskeys({this.deviceSecret = 'device-a', this.supported = true});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<String> register({required String userName}) async {
    prompts++;
    if (cancelNext) {
      cancelNext = false;
      throw const PasskeyException('cancelled', cancelled: true);
    }
    return 'cred-${userName.hashCode}';
  }

  @override
  Future<Uint8List> prfSecret({required String credentialId, required Uint8List salt}) async {
    prompts++;
    if (cancelNext) {
      cancelNext = false;
      throw const PasskeyException('cancelled', cancelled: true);
    }
    return Uint8List.fromList(Hmac(sha256, utf8.encode(deviceSecret)).convert([...utf8.encode(credentialId), ...salt]).bytes);
  }
}

const pin = '123456';

StellarKeyVault vaultWith(FakePasskeys p, [InMemoryVaultStore? s]) =>
    StellarKeyVault(store: s ?? InMemoryVaultStore(), kdfIterations: 1000, passkeys: p);

void main() {
  test('switching to a passkey requires a saved recovery key and the PIN', () async {
    final passkeys = FakePasskeys();
    final vault = vaultWith(passkeys);
    await vault.createWallet(pin: pin);
    await expectLater(vault.enablePasskey(pin: pin),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.backupRequired)));
    await vault.markBackedUp();
    await expectLater(vault.enablePasskey(pin: '000000'),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.pinMismatch)));
    expect(await vault.usesPasskey(), isFalse);

    await vault.enablePasskey(pin: pin);
    expect(await vault.usesPasskey(), isTrue);
    expect(await vault.isBackedUp(), isTrue, reason: 'same wallet, still backed up');
  });

  test('with a passkey: the PIN no longer works, the passkey signs real transactions', () async {
    final passkeys = FakePasskeys();
    final vault = vaultWith(passkeys);
    final account = await vault.createWallet(pin: pin);
    await vault.markBackedUp();
    await vault.enablePasskey(pin: pin);

    await expectLater(vault.verifyPin(pin), throwsA(isA<StellarVaultException>()));

    final tx = TransactionBuilder(Account(account, BigInt.from(1)))
        .addOperation(BumpSequenceOperationBuilder(BigInt.from(5)).build())
        .build();
    final signed = await vault.signTransactionXdr(tx.toEnvelopeXdrBase64(),
        pin: StellarKeyVault.passkey, networkPassphrase: Network.TESTNET.networkPassphrase);
    final parsed = AbstractTransaction.fromEnvelopeXdrString(signed) as Transaction;
    expect(parsed.signatures, hasLength(1));
    expect(KeyPair.fromAccountId(account).verify(parsed.hash(Network.TESTNET), parsed.signatures.single.signature.signature), isTrue);

    final seed = await vault.exportRecoveryKey(pin: StellarKeyVault.passkey);
    expect(KeyPair.fromSecretSeed(seed).accountId, account);
  });

  test('the stored data alone is useless: another device\'s passkey cannot unlock it', () async {
    final s = InMemoryVaultStore();
    final mine = vaultWith(FakePasskeys(deviceSecret: 'my-phone'), s);
    await mine.createWallet(pin: pin);
    await mine.markBackedUp();
    await mine.enablePasskey(pin: pin);
    expect(s.values.values.join(), isNot(contains('"iterations"')), reason: 'no PIN-encrypted copy left behind');

    final thief = vaultWith(FakePasskeys(deviceSecret: 'thief-laptop'), s);
    await expectLater(thief.verifyPin(StellarKeyVault.passkey), completion(isFalse));
    await expectLater(thief.exportRecoveryKey(pin: StellarKeyVault.passkey),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.pinMismatch)));
  });

  test('a cancelled passkey prompt is reported as cancelled and changes nothing', () async {
    final passkeys = FakePasskeys();
    final vault = vaultWith(passkeys);
    await vault.createWallet(pin: pin);
    await vault.markBackedUp();

    passkeys.cancelNext = true;
    await expectLater(vault.enablePasskey(pin: pin),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.passkeyCancelled)));
    expect(await vault.usesPasskey(), isFalse);
    expect(await vault.verifyPin(pin), isTrue, reason: 'PIN still works after a cancelled switch');

    await vault.enablePasskey(pin: pin);
    passkeys.cancelNext = true;
    await expectLater(vault.exportRecoveryKey(pin: StellarKeyVault.passkey),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.passkeyCancelled)));
    expect(await vault.verifyPin(StellarKeyVault.passkey), isTrue, reason: 'cancels never lock the wallet');
  });

  test('switching back to a PIN needs the passkey; PIN-only wallets reject the passkey sentinel', () async {
    final vault = vaultWith(FakePasskeys());
    await vault.createWallet(pin: pin);
    await expectLater(vault.verifyPin(StellarKeyVault.passkey), throwsA(isA<StellarVaultException>()));
    await vault.markBackedUp();
    await vault.enablePasskey(pin: pin);
    await expectLater(vault.changePin(currentPin: pin, newPin: '654321'), throwsA(isA<StellarVaultException>()));

    await vault.disablePasskey(newPin: '654321');
    expect(await vault.usesPasskey(), isFalse);
    expect(await vault.verifyPin('654321'), isTrue);
  });
}

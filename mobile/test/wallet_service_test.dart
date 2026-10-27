import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/stellar/stellar_network.dart';
import 'package:flowpay_mobile/core/wallet/wallet_service.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';
import 'package:flowpay_mobile/core/safety/signing_coordinator.dart';

/// In-memory mock wallet service for deterministic notifier tests.
class MockWalletService implements WalletService {
  bool backedUp = false;

  @override
  Future<bool> isRecoveryKeyBackedUp() async => backedUp;

  @override
  Future<void> markRecoveryKeyBackedUp() async => backedUp = true;

  String? _address;
  String? _pin;

  @override
  Future<bool> hasWallet() async => _address != null;

  @override
  Future<String> createWallet({required String pin}) async {
    if (_address != null) {
      throw const StellarVaultException(StellarVaultErrorCode.walletAlreadyExists, 'Wallet already exists');
    }
    _address = 'GMOCKWALLETADDRESS0001';
    _pin = pin;
    return _address!;
  }

  @override
  Future<String> importWallet({required String recoveryKey, required String pin}) => createWallet(pin: pin);

  @override
  Future<String?> getWalletAddress() async => _address;

  @override
  Future<void> deleteWallet({required String pin}) async {
    if (pin != _pin) throw const StellarVaultException(StellarVaultErrorCode.pinMismatch, 'Incorrect PIN.');
    _address = null;
    _pin = null;
  }

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<bool> matchPin(String pin) async => _pin == pin;

  @override
  Future<void> changePin({required String currentPin, required String newPin}) async {
    if (currentPin != _pin) throw const StellarVaultException(StellarVaultErrorCode.pinMismatch, 'Incorrect PIN.');
    _pin = newPin;
  }

  @override
  Future<String> exportRecoveryKey({required String pin}) async => 'SMOCK';
}

class _FailingStore implements VaultStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async => throw Exception('keychain locked');
  @override
  Future<void> delete(String key) async {}
}

StellarKeyVault _vault({DateTime Function()? clock, VaultStore? store}) =>
    StellarKeyVault(store: store ?? InMemoryVaultStore(), kdfIterations: 1000, clock: clock);

Matcher _vaultError(StellarVaultErrorCode code) =>
    isA<StellarVaultException>().having((e) => e.code, 'code', code);

String _unsignedPaymentXdr(String sourceAccountId) {
  final tx = TransactionBuilder(Account(sourceAccountId, BigInt.from(100)))
      .addOperation(PaymentOperationBuilder(KeyPair.random().accountId, Asset.NATIVE, '1').build())
      .build();
  return tx.toEnvelopeXdrBase64();
}

void main() {
  // ---------------------------------------------------------------------------
  group('WalletState — immutable model', () {
    test('.noWallet(), .creating(), .ready(), .error() flags', () {
      expect(const WalletState.noWallet().isNoWallet, isTrue);
      expect(const WalletState.creating().isCreating, isTrue);
      const ready = WalletState.ready(address: 'GABC');
      expect(ready.isReady, isTrue);
      expect(ready.hasPin, isTrue, reason: 'a wallet cannot exist without a PIN');
      expect(const WalletState.error('x').errorMessage, 'x');
    });

    test('copyWith() preserves and overrides fields', () {
      const s = WalletState.ready(address: 'GABC');
      expect(s.copyWith(errorMessage: 'e').address, 'GABC');
      expect(s.copyWith(errorMessage: 'e').errorMessage, 'e');
    });
  });

  // ---------------------------------------------------------------------------
  group('WalletStateNotifier — provisioning lifecycle', () {
    late MockWalletService mock;
    late WalletStateNotifier notifier;

    setUp(() {
      mock = MockWalletService();
      notifier = WalletStateNotifier(mock);
    });
    tearDown(() => notifier.dispose());

    test('starts as noWallet', () async {
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isNoWallet, isTrue);
    });

    test('createWallet(pin) → ready', () async {
      final address = await notifier.createWallet(pin: '123456');
      expect(address, 'GMOCKWALLETADDRESS0001');
      expect(notifier.state.isReady, isTrue);
    });

    test('createWallet() on an existing wallet recovers to ready', () async {
      await notifier.createWallet(pin: '123456');
      expect(await notifier.createWallet(pin: '123456'), 'GMOCKWALLETADDRESS0001');
      expect(notifier.state.isReady, isTrue);
    });

    test('deleteWallet() needs the right PIN', () async {
      await notifier.createWallet(pin: '123456');
      expect(await notifier.deleteWallet(pin: '000000'), isFalse);
      expect(notifier.state.isReady, isTrue);
      expect(await notifier.deleteWallet(pin: '123456'), isTrue);
      expect(notifier.state.isNoWallet, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('StellarKeyVault — real keys, real encryption', () {
    test('creates a valid Stellar account ID and persists only ciphertext', () async {
      final store = InMemoryVaultStore();
      final vault = _vault(store: store);
      final accountId = await vault.createWallet(pin: '123456');

      expect(StrKey.isValidStellarAccountId(accountId), isTrue);
      expect(await vault.publicKey(), accountId);
      final persisted = store.values.values.join();
      final seed = await vault.exportRecoveryKey(pin: '123456');
      expect(persisted.contains(seed), isFalse, reason: 'secret seed must never be stored in plaintext');
      expect(persisted.contains('123456'), isFalse, reason: 'PIN must never be stored');
    });

    test('wrong PIN is rejected; correct PIN verifies', () async {
      final vault = _vault();
      await vault.createWallet(pin: '123456');
      expect(await vault.verifyPin('654321'), isFalse);
      expect(await vault.verifyPin('123456'), isTrue);
    });

    test('rejects malformed PINs before touching the key', () async {
      final vault = _vault();
      await expectLater(() => vault.createWallet(pin: '12345'), throwsA(_vaultError(StellarVaultErrorCode.pinInvalid)));
      await expectLater(() => vault.createWallet(pin: 'abcdef'), throwsA(_vaultError(StellarVaultErrorCode.pinInvalid)));
    });

    test('refuses to overwrite an existing wallet', () async {
      final vault = _vault();
      await vault.createWallet(pin: '123456');
      await expectLater(() => vault.createWallet(pin: '123456'), throwsA(_vaultError(StellarVaultErrorCode.walletAlreadyExists)));
    });

    test('operations without a wallet fail honestly', () async {
      await expectLater(() => _vault().verifyPin('123456'), throwsA(_vaultError(StellarVaultErrorCode.noWallet)));
    });

    test('locks out after 5 wrong PINs, escalating, and unlocks after the wait', () async {
      var now = DateTime(2026, 10, 26, 12);
      final vault = _vault(clock: () => now);
      await vault.createWallet(pin: '123456');

      for (var i = 0; i < StellarKeyVault.freeAttempts; i++) {
        expect(await vault.verifyPin('000000'), isFalse);
      }
      // Even the correct PIN is refused during lockout.
      await expectLater(() => vault.verifyPin('123456'), throwsA(_vaultError(StellarVaultErrorCode.lockedOut)));

      now = now.add(const Duration(seconds: 31));
      expect(await vault.verifyPin('123456'), isTrue, reason: 'lockout expires after 30s');
      // Success resets the counter.
      expect(await vault.verifyPin('000000'), isFalse);
      expect(await vault.verifyPin('123456'), isTrue);
    });

    test('changePin re-encrypts: old PIN stops working, same account', () async {
      final vault = _vault();
      final id = await vault.createWallet(pin: '123456');
      await vault.changePin(currentPin: '123456', newPin: '999999');
      expect(await vault.verifyPin('123456'), isFalse);
      expect(await vault.verifyPin('999999'), isTrue);
      expect(await vault.publicKey(), id);
    });

    test('deleteWallet requires the PIN', () async {
      final vault = _vault();
      await vault.createWallet(pin: '123456');
      await expectLater(() => vault.deleteWallet(pin: '000000'), throwsA(_vaultError(StellarVaultErrorCode.pinMismatch)));
      await vault.deleteWallet(pin: '123456');
      expect(await vault.hasWallet(), isFalse);
      expect(await vault.publicKey(), isNull);
    });

    test('recovery key export → import restores the same account', () async {
      final a = _vault();
      final id = await a.createWallet(pin: '123456');
      final seed = await a.exportRecoveryKey(pin: '123456');

      final b = _vault();
      expect(await b.importWallet(secretSeed: seed, pin: '222222'), id);
      await expectLater(() => _vault().importWallet(secretSeed: 'not-a-seed', pin: '222222'), throwsA(isA<StellarVaultException>()));
    });

    test('storage failures propagate (no silent "saved" wallet)', () async {
      final vault = _vault(store: _FailingStore());
      await expectLater(() => vault.createWallet(pin: '123456'), throwsA(_vaultError(StellarVaultErrorCode.storageFailure)));
    });
  });

  // ---------------------------------------------------------------------------
  group('StellarWalletSigner — signatures verify against the public key', () {
    test('signTransactionXdr produces a valid ed25519 signature for this network', () async {
      final id = await StellarKeyVault.instance.createWallet(pin: '123456');
      final signed = await const StellarWalletSigner().signTransactionXdr(_unsignedPaymentXdr(id), pin: '123456');

      final tx = AbstractTransaction.fromEnvelopeXdrString(signed) as Transaction;
      expect(tx.signatures, hasLength(1));
      final hash = tx.hash(Network(StellarNetwork.current.passphrase));
      final ok = KeyPair.fromAccountId(id).verify(hash, tx.signatures.first.signature.signature);
      expect(ok, isTrue);
    });

    test('signMessage signature verifies; wrong PIN refuses to sign', () async {
      final id = await StellarKeyVault.instance.createWallet(pin: '123456');
      const signer = StellarWalletSigner();
      final sigHex = await signer.signMessage('hello', pin: '123456');
      final sig = Uint8List.fromList([for (var i = 0; i < sigHex.length; i += 2) int.parse(sigHex.substring(i, i + 2), radix: 16)]);
      expect(KeyPair.fromAccountId(id).verify(Uint8List.fromList(utf8.encode('hello')), sig), isTrue);
      await expectLater(() => signer.signMessage('hello', pin: '000000'), throwsA(_vaultError(StellarVaultErrorCode.pinMismatch)));
    });

    test('signTransactionHash rejects non-hex input', () async {
      await StellarKeyVault.instance.createWallet(pin: '123456');
      await expectLater(() => const StellarWalletSigner().signTransactionHash('0xZZ', pin: '123456'), throwsA(isA<StellarVaultException>()));
    });
  });

  // ---------------------------------------------------------------------------
  group('SigningCoordinator — delegation & error propagation', () {
    test('signs with the injected signer', () async {
      final sig = await SigningCoordinator.authorizeAndSign(hashToSign: '0xabcd', pin: '123456', signer: _MockWalletSigner());
      expect(sig, 'MOCK_SIG');
    });

    test('propagates signer failures (no silent success)', () async {
      expect(
        () => SigningCoordinator.authorizeAndSign(hashToSign: '0x1111', pin: '000000', signer: _FailingWalletSigner()),
        throwsA(isA<StellarVaultException>()),
      );
    });

    test('SigningCancelledException formats its message', () {
      expect(const SigningCancelledException().toString(), contains('cancelled'));
    });
  });
}

class _MockWalletSigner implements WalletSigner {
  @override
  Future<String> signMessage(String message, {required String pin}) async => 'MOCK_SIG';
  @override
  Future<String> signTransactionHash(String hashHex, {required String pin}) async => 'MOCK_SIG';
  @override
  Future<String> signTransactionXdr(String envelopeXdr, {required String pin}) async => 'MOCK_XDR';
}

class _FailingWalletSigner implements WalletSigner {
  static const _err = StellarVaultException(StellarVaultErrorCode.signingFailed, 'signing failed');
  @override
  Future<String> signMessage(String message, {required String pin}) async => throw _err;
  @override
  Future<String> signTransactionHash(String hashHex, {required String pin}) async => throw _err;
  @override
  Future<String> signTransactionXdr(String envelopeXdr, {required String pin}) async => throw _err;
}

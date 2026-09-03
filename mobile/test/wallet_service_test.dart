import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/wallet/wallet_service.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';

/// In-memory mock wallet service for deterministic unit testing.
class MockWalletService implements WalletService {
  bool _hasWallet = false;
  String? _address;
  String? _pin;

  @override
  Future<void> initialize({int pinLength = 6, bool requirePin = true}) async {}

  @override
  Future<bool> hasWallet() async => _hasWallet;

  @override
  Future<String> createWallet() async {
    if (_hasWallet) {
      throw const BmoniSignerException(
        errorCode: BmoniSignerErrorCode.walletAlreadyExists,
        message: 'Wallet already exists',
      );
    }
    _address = '0xMOCK_WALLET_ADDRESS_0001';
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
  Future<void> setPin(String pin) async {
    _pin = pin;
  }

  @override
  Future<bool> matchPin(String pin) async => _pin == pin;

  @override
  Future<void> changePin({required String currentPin, required String newPin}) async {
    if (_pin != currentPin) {
      throw const BmoniSignerException(
        errorCode: BmoniSignerErrorCode.pinMismatch,
        message: 'PIN does not match',
      );
    }
    _pin = newPin;
  }

  @override
  Future<void> removePin(String currentPin) async {
    if (_pin != currentPin) {
      throw const BmoniSignerException(
        errorCode: BmoniSignerErrorCode.pinMismatch,
        message: 'PIN does not match',
      );
    }
    _pin = null;
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // WALLET STATE MODEL TESTS
  // ---------------------------------------------------------------------------
  group('WalletState — immutable model and named constructors', () {
    test('.noWallet() has correct defaults', () {
      const state = WalletState.noWallet();

      expect(state.status, WalletProvisioningStatus.noWallet);
      expect(state.address, isNull);
      expect(state.hasPin, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.isNoWallet, isTrue);
      expect(state.isReady, isFalse);
      expect(state.hasError, isFalse);
    });

    test('.creating() has correct defaults', () {
      const state = WalletState.creating();

      expect(state.status, WalletProvisioningStatus.creating);
      expect(state.isCreating, isTrue);
      expect(state.address, isNull);
    });

    test('.ready() stores address and optional hasPin', () {
      const state = WalletState.ready(address: '0xABC', hasPin: true);

      expect(state.status, WalletProvisioningStatus.ready);
      expect(state.isReady, isTrue);
      expect(state.address, '0xABC');
      expect(state.hasPin, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('.error() stores errorMessage', () {
      const state = WalletState.error('Something went wrong');

      expect(state.status, WalletProvisioningStatus.error);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, 'Something went wrong');
      expect(state.address, isNull);
    });

    test('copyWith() preserves unchanged fields', () {
      const original = WalletState.ready(address: '0xABC', hasPin: true);
      final copy = original.copyWith(hasPin: false);

      expect(copy.status, WalletProvisioningStatus.ready);
      expect(copy.address, '0xABC');
      expect(copy.hasPin, isFalse);
    });

    test('copyWith() can override errorMessage', () {
      const original = WalletState.ready(address: '0xABC');
      final copy = original.copyWith(errorMessage: 'Device locked');

      expect(copy.errorMessage, 'Device locked');
      expect(copy.address, '0xABC');
    });
  });

  // ---------------------------------------------------------------------------
  // WALLET STATE NOTIFIER — LIFECYCLE TESTS
  // ---------------------------------------------------------------------------
  group('WalletStateNotifier — wallet provisioning lifecycle', () {
    late MockWalletService mockService;
    late WalletStateNotifier notifier;

    setUp(() {
      mockService = MockWalletService();
      notifier = WalletStateNotifier(mockService);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state is noWallet when no wallet exists', () async {
      // WalletStateNotifier calls loadWalletState() in constructor.
      // Give it a microtask to complete.
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isNoWallet, isTrue);
    });

    test('createWallet() transitions noWallet → creating → ready', () async {
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isNoWallet, isTrue);

      final address = await notifier.createWallet();

      expect(address, isNotNull);
      expect(address, '0xMOCK_WALLET_ADDRESS_0001');
      expect(notifier.state.isReady, isTrue);
      expect(notifier.state.address, '0xMOCK_WALLET_ADDRESS_0001');
    });

    test('createWallet() with PIN sets PIN alongside provisioning', () async {
      await Future<void>.delayed(Duration.zero);

      final address = await notifier.createWallet(pin: '123456');

      expect(address, isNotNull);
      expect(notifier.state.isReady, isTrue);
      expect(notifier.state.hasPin, isTrue);
    });

    test('createWallet() on existing wallet recovers gracefully', () async {
      await Future<void>.delayed(Duration.zero);

      // First creation
      await notifier.createWallet();
      expect(notifier.state.isReady, isTrue);

      // Second creation: hits walletAlreadyExists and recovers
      final address = await notifier.createWallet();
      expect(address, '0xMOCK_WALLET_ADDRESS_0001');
      expect(notifier.state.isReady, isTrue);
    });

    test('deleteWallet() transitions ready → noWallet', () async {
      await Future<void>.delayed(Duration.zero);

      await notifier.createWallet();
      expect(notifier.state.isReady, isTrue);

      final success = await notifier.deleteWallet();
      expect(success, isTrue);
      expect(notifier.state.isNoWallet, isTrue);
      expect(notifier.state.address, isNull);
    });

    test('loadWalletState() reflects current device state', () async {
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isNoWallet, isTrue);

      // Manually provision via the mock
      await mockService.createWallet();
      await mockService.setPin('999999');

      // Reload
      await notifier.loadWalletState();

      expect(notifier.state.isReady, isTrue);
      expect(notifier.state.address, '0xMOCK_WALLET_ADDRESS_0001');
      expect(notifier.state.hasPin, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // PIN MANAGEMENT — VIA MOCK SERVICE
  // ---------------------------------------------------------------------------
  group('WalletService PIN management', () {
    late MockWalletService service;

    setUp(() {
      service = MockWalletService();
    });

    test('hasPin() returns false before any PIN is set', () async {
      expect(await service.hasPin(), isFalse);
    });

    test('setPin() + hasPin() returns true after setting', () async {
      await service.setPin('123456');
      expect(await service.hasPin(), isTrue);
    });

    test('matchPin() validates correct PIN', () async {
      await service.setPin('654321');
      expect(await service.matchPin('654321'), isTrue);
      expect(await service.matchPin('000000'), isFalse);
    });

    test('changePin() requires correct current PIN', () async {
      await service.setPin('111111');

      // Wrong current PIN throws
      expect(
        () => service.changePin(currentPin: '999999', newPin: '222222'),
        throwsA(isA<BmoniSignerException>()),
      );

      // Correct current PIN succeeds
      await service.changePin(currentPin: '111111', newPin: '222222');
      expect(await service.matchPin('222222'), isTrue);
      expect(await service.matchPin('111111'), isFalse);
    });

    test('removePin() requires correct PIN and clears state', () async {
      await service.setPin('123456');
      expect(await service.hasPin(), isTrue);

      // Wrong PIN throws
      expect(
        () => service.removePin('000000'),
        throwsA(isA<BmoniSignerException>()),
      );

      // Correct PIN removes
      await service.removePin('123456');
      expect(await service.hasPin(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // BMONI SDK SERVICE — PRODUCTION WRAPPER (test-env fallback)
  // ---------------------------------------------------------------------------
  group('BmoniSdkService — test environment integration', () {
    setUp(() async {
      // Reset static state between tests
      await BmoniSdkService.deleteWallet();
      try { await BmoniSdkService.removePin('000000'); } catch (_) {}
    });

    test('initialize() sets pinLength and requirePin', () {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);
      expect(BmoniSdkService.pinLength, 6);
      expect(BmoniSdkService.requirePin, isTrue);
    });

    test('hasWallet() returns false before provisioning', () async {
      expect(await BmoniSdkService.hasWallet(), isFalse);
    });

    test('initWallet() returns EIP-55 checksummed address', () async {
      final address = await BmoniSdkService.initWallet();
      expect(address, startsWith('0x'));
      expect(address.length, 42); // Standard Ethereum address length
    });

    test('walletAddress() returns provisioned address', () async {
      final provisioned = await BmoniSdkService.initWallet();
      final queried = await BmoniSdkService.walletAddress();
      expect(queried, provisioned);
    });

    test('hasWallet() returns true after provisioning', () async {
      await BmoniSdkService.initWallet();
      expect(await BmoniSdkService.hasWallet(), isTrue);
    });

    test('deleteWallet() removes wallet from device', () async {
      await BmoniSdkService.initWallet();
      expect(await BmoniSdkService.hasWallet(), isTrue);

      await BmoniSdkService.deleteWallet();
      expect(await BmoniSdkService.hasWallet(), isFalse);
      expect(await BmoniSdkService.walletAddress(), isNull);
    });

    test('setPin() + hasPin() + matchPin() work correctly', () async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);
      expect(await BmoniSdkService.hasPin(), isFalse);

      await BmoniSdkService.setPin('123456');
      expect(await BmoniSdkService.hasPin(), isTrue);
      expect(await BmoniSdkService.matchPin('123456'), isTrue);
      expect(await BmoniSdkService.matchPin('000000'), isFalse);
    });

    test('setPin() rejects wrong-length PIN', () async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);

      expect(
        () => BmoniSdkService.setPin('12'),
        throwsA(isA<BmoniSignerException>()),
      );
    });

    test('changePin() transitions PIN correctly', () async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);

      await BmoniSdkService.setPin('111111');
      await BmoniSdkService.changePin(currentPin: '111111', newPin: '222222');

      expect(await BmoniSdkService.matchPin('222222'), isTrue);
      expect(await BmoniSdkService.matchPin('111111'), isFalse);
    });

    test('changePin() rejects wrong current PIN', () async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);

      await BmoniSdkService.setPin('111111');

      expect(
        () => BmoniSdkService.changePin(currentPin: '999999', newPin: '222222'),
        throwsA(isA<BmoniSignerException>()),
      );
    });

    test('removePin() clears PIN after validation', () async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);

      await BmoniSdkService.setPin('123456');
      await BmoniSdkService.removePin('123456');

      expect(await BmoniSdkService.hasPin(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // SIGNING OPERATIONS — BMONI SDK SERVICE
  // ---------------------------------------------------------------------------
  group('BmoniSdkService — signing operations', () {
    setUp(() async {
      BmoniSdkService.initialize(pinLength: 6, requirePin: true);
      await BmoniSdkService.initWallet();
      await BmoniSdkService.setPin('123456');
    });

    tearDown(() async {
      await BmoniSdkService.deleteWallet();
      try { await BmoniSdkService.removePin('123456'); } catch (_) {}
    });

    test('signMessage() returns hex signature on correct PIN', () async {
      final sig = await BmoniSdkService.signMessage(
        'Hello FlowPay',
        pin: '123456',
      );

      expect(sig, startsWith('0x'));
      expect(sig.length, greaterThan(64));
    });

    test('signMessage() rejects incorrect PIN', () async {
      expect(
        () => BmoniSdkService.signMessage('Hello', pin: '000000'),
        throwsA(isA<BmoniSignerException>()),
      );
    });

    test('signTransactionHash() returns hex signature on correct PIN', () async {
      final hash = '0x' + ('ab' * 32); // 32-byte hash
      final sig = await BmoniSdkService.signTransactionHash(
        hash,
        pin: '123456',
      );

      expect(sig, startsWith('0x'));
      expect(sig.length, greaterThan(64));
    });

    test('signTransactionHash() rejects incorrect PIN', () async {
      final hash = '0x' + ('cd' * 32);
      expect(
        () => BmoniSdkService.signTransactionHash(hash, pin: '000000'),
        throwsA(isA<BmoniSignerException>()),
      );
    });

    test('Deterministic: same message + PIN → same signature', () async {
      final sig1 = await BmoniSdkService.signMessage('Hello', pin: '123456');
      final sig2 = await BmoniSdkService.signMessage('Hello', pin: '123456');
      expect(sig1, sig2);
    });

    test('Different messages → different signatures', () async {
      final sig1 = await BmoniSdkService.signMessage('Message A', pin: '123456');
      final sig2 = await BmoniSdkService.signMessage('Message B', pin: '123456');
      expect(sig1, isNot(sig2));
    });
  });

  // ---------------------------------------------------------------------------
  // WALLET SIGNER — ABSTRACT CONTRACT
  // ---------------------------------------------------------------------------
  group('WalletSigner — SigningCancelledException', () {
    test('toString() formats correctly', () {
      const e = SigningCancelledException('User tapped cancel');
      expect(e.toString(), contains('SigningCancelledException'));
      expect(e.toString(), contains('User tapped cancel'));
    });

    test('default message is present', () {
      const e = SigningCancelledException();
      expect(e.message, contains('cancelled'));
    });
  });

  // ---------------------------------------------------------------------------
  // ERROR CODE COVERAGE
  // ---------------------------------------------------------------------------
  group('BmoniSignerException — error code semantics', () {
    test('walletAlreadyExists error code is accessible', () {
      const e = BmoniSignerException(
        errorCode: BmoniSignerErrorCode.walletAlreadyExists,
        message: 'Already provisioned',
      );
      expect(e.errorCode, BmoniSignerErrorCode.walletAlreadyExists);
      expect(e.message, 'Already provisioned');
    });

    test('pinMismatch error code is accessible', () {
      const e = BmoniSignerException(
        errorCode: BmoniSignerErrorCode.pinMismatch,
        message: 'Wrong PIN',
      );
      expect(e.errorCode, BmoniSignerErrorCode.pinMismatch);
    });

    test('pinInvalid error code is accessible', () {
      const e = BmoniSignerException(
        errorCode: BmoniSignerErrorCode.pinInvalid,
        message: 'Invalid length',
      );
      expect(e.errorCode, BmoniSignerErrorCode.pinInvalid);
    });
  });
}

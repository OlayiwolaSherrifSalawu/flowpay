import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../stellar/stellar_key_vault.dart';

/// Provisioning lifecycle status of the on-device Stellar wallet.
enum WalletProvisioningStatus {
  /// No keypair currently provisioned on device.
  noWallet,

  /// In-flight key generation & encryption.
  creating,

  /// Keypair provisioned, encrypted under the PIN, and ready.
  ready,

  /// An error occurred during provisioning or querying.
  error,
}

/// Immutable state describing on-device wallet readiness.
class WalletState {
  final WalletProvisioningStatus status;

  /// Stellar account ID (G...).
  final String? address;
  final bool hasPin;
  final String? errorMessage;

  const WalletState({
    required this.status,
    this.address,
    this.hasPin = false,
    this.errorMessage,
  });

  const WalletState.noWallet()
      : status = WalletProvisioningStatus.noWallet,
        address = null,
        hasPin = false,
        errorMessage = null;

  const WalletState.creating()
      : status = WalletProvisioningStatus.creating,
        address = null,
        hasPin = false,
        errorMessage = null;

  const WalletState.ready({required String this.address, this.hasPin = true})
      : status = WalletProvisioningStatus.ready,
        errorMessage = null;

  const WalletState.error(String this.errorMessage)
      : status = WalletProvisioningStatus.error,
        address = null,
        hasPin = false;

  bool get isReady => status == WalletProvisioningStatus.ready;
  bool get isCreating => status == WalletProvisioningStatus.creating;
  bool get isNoWallet => status == WalletProvisioningStatus.noWallet;
  bool get hasError => status == WalletProvisioningStatus.error;

  WalletState copyWith({
    WalletProvisioningStatus? status,
    String? address,
    bool? hasPin,
    String? errorMessage,
  }) {
    return WalletState(
      status: status ?? this.status,
      address: address ?? this.address,
      hasPin: hasPin ?? this.hasPin,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Abstract contract for FlowPay's on-device wallet.
///
/// The wallet's secret key is encrypted under the PIN, so "has a wallet" and
/// "has a PIN" are the same thing: a wallet cannot exist without one.
abstract class WalletService {
  /// Check whether an on-device wallet keypair has been provisioned.
  Future<bool> hasWallet();

  /// Provision a new on-device Stellar keypair protected by [pin]. Returns the account ID.
  Future<String> createWallet({required String pin});

  /// Restore a wallet from its recovery key (S... secret seed).
  Future<String> importWallet({required String recoveryKey, required String pin});

  /// The Stellar account ID (G...) of the wallet, or null.
  Future<String?> getWalletAddress();

  /// Securely delete the on-device wallet. Requires the PIN.
  Future<void> deleteWallet({required String pin});

  /// Whether a PIN is configured (true exactly when a wallet exists).
  Future<bool> hasPin();

  /// Verify the PIN without throwing on mismatch. Throws [StellarVaultException]
  /// for lockouts and storage failures.
  Future<bool> matchPin(String pin);

  /// Re-encrypt the wallet under a new PIN.
  Future<void> changePin({required String currentPin, required String newPin});

  /// Reveal the recovery key for backup. Requires the PIN.
  Future<String> exportRecoveryKey({required String pin});

  /// Whether the user confirmed saving the recovery key for this wallet.
  Future<bool> isRecoveryKeyBackedUp();

  /// Records that the user saved (and re-typed part of) the recovery key.
  Future<void> markRecoveryKeyBackedUp();
}

/// Production implementation backed by [StellarKeyVault].
class StellarWalletService implements WalletService {
  final StellarKeyVault? _vaultOverride;

  const StellarWalletService([this._vaultOverride]);

  StellarKeyVault get _vault => _vaultOverride ?? StellarKeyVault.instance;

  @override
  Future<bool> hasWallet() => _vault.hasWallet();

  @override
  Future<String> createWallet({required String pin}) => _vault.createWallet(pin: pin);

  @override
  Future<String> importWallet({required String recoveryKey, required String pin}) =>
      _vault.importWallet(secretSeed: recoveryKey, pin: pin);

  @override
  Future<String?> getWalletAddress() => _vault.publicKey();

  @override
  Future<void> deleteWallet({required String pin}) => _vault.deleteWallet(pin: pin);

  @override
  Future<bool> hasPin() => _vault.hasWallet();

  @override
  Future<bool> matchPin(String pin) => _vault.verifyPin(pin);

  @override
  Future<void> changePin({required String currentPin, required String newPin}) =>
      _vault.changePin(currentPin: currentPin, newPin: newPin);

  @override
  Future<String> exportRecoveryKey({required String pin}) => _vault.exportRecoveryKey(pin: pin);

  @override
  Future<bool> isRecoveryKeyBackedUp() => _vault.isBackedUp();

  @override
  Future<void> markRecoveryKeyBackedUp() => _vault.markBackedUp();
}

/// StateNotifier coordinating on-device wallet lifecycle and UI states.
class WalletStateNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService;

  WalletStateNotifier(this._walletService)
      : super(const WalletState.noWallet()) {
    loadWalletState();
  }

  /// Refreshes and inspects device state.
  Future<void> loadWalletState() async {
    try {
      final address = await _walletService.getWalletAddress();
      state = address == null ? const WalletState.noWallet() : WalletState.ready(address: address);
    } catch (e) {
      state = WalletState.error(e.toString());
    }
  }

  /// Provisions a new on-device wallet protected by [pin].
  Future<String?> createWallet({required String pin}) async {
    state = const WalletState.creating();
    try {
      final address = await _walletService.createWallet(pin: pin);
      state = WalletState.ready(address: address);
      return address;
    } on StellarVaultException catch (e) {
      if (e.code == StellarVaultErrorCode.walletAlreadyExists) {
        final existing = await _walletService.getWalletAddress();
        if (existing != null) {
          state = WalletState.ready(address: existing);
          return existing;
        }
      }
      state = WalletState.error('Wallet setup failed: ${e.message}');
      return null;
    } catch (e) {
      state = WalletState.error('Failed to create wallet: $e');
      return null;
    }
  }

  /// Deletes the wallet from device storage and resets state.
  Future<bool> deleteWallet({required String pin}) async {
    try {
      await _walletService.deleteWallet(pin: pin);
      state = const WalletState.noWallet();
      return true;
    } on StellarVaultException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

/// Riverpod provider for the active [WalletService].
final walletServiceProvider = Provider<WalletService>((ref) {
  return const StellarWalletService();
});

/// Riverpod provider for reactive [WalletState].
final walletStateProvider =
    StateNotifierProvider<WalletStateNotifier, WalletState>((ref) {
  final service = ref.watch(walletServiceProvider);
  return WalletStateNotifier(service);
});

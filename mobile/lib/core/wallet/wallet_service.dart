import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../bmoni_sdk/bmoni_sdk_service.dart';

/// Provisioning lifecycle status of the on-device B-Key wallet.
enum WalletProvisioningStatus {
  /// No hardware keypair currently provisioned on device.
  noWallet,

  /// In-flight key generation & enclave enrollment.
  creating,

  /// Hardware keypair provisioned, verified, and ready.
  ready,

  /// An error occurred during provisioning or querying.
  error,
}

/// Immutable state describing on-device wallet readiness.
class WalletState {
  final WalletProvisioningStatus status;
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

  const WalletState.ready({required String this.address, this.hasPin = false})
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

/// Abstract contract for FlowPay's on-device B-Key wallet service.
abstract class WalletService {
  /// Initialize the BMONI Embedded SDK and establish the security PIN policy.
  Future<void> initialize({int pinLength = 6, bool requirePin = true});

  /// Check whether an on-device wallet keypair has been provisioned.
  Future<bool> hasWallet();

  /// Provision a new on-device Ethereum wallet keypair.
  Future<String> createWallet();

  /// Retrieve the EIP-55 checksummed public Ethereum address of the wallet.
  Future<String?> getWalletAddress();

  /// Securely delete the on-device wallet keypair from hardware storage.
  Future<void> deleteWallet({String? pin});

  /// Check whether a security PIN is currently configured.
  Future<bool> hasPin();

  /// Persist a new security PIN as a salted PBKDF2 digest.
  Future<void> setPin(String pin);

  /// Verify whether the provided PIN matches the stored digest without throwing.
  Future<bool> matchPin(String pin);

  /// Change the user's security PIN after verifying the current PIN.
  Future<void> changePin({required String currentPin, required String newPin});

  /// Remove the stored PIN digest after verifying the current PIN.
  Future<void> removePin(String currentPin);
}

/// Production implementation of [WalletService] backed by `BmoniSdkService` and `bmoni_embedded_sdk`.
class BmoniWalletService implements WalletService {
  const BmoniWalletService();

  @override
  Future<void> initialize({int pinLength = 6, bool requirePin = true}) async {
    await BmoniSdkService.initialize(pinLength: pinLength, requirePin: requirePin);
  }

  @override
  Future<bool> hasWallet() async {
    return await BmoniSdkService.hasWallet();
  }

  @override
  Future<String> createWallet() async {
    return await BmoniSdkService.initWallet();
  }

  @override
  Future<String?> getWalletAddress() async {
    return await BmoniSdkService.walletAddress();
  }

  @override
  Future<void> deleteWallet({String? pin}) async {
    await BmoniSdkService.deleteWallet(pin: pin);
  }

  @override
  Future<bool> hasPin() async {
    return await BmoniSdkService.hasPin();
  }

  @override
  Future<void> setPin(String pin) async {
    await BmoniSdkService.setPin(pin);
  }

  @override
  Future<bool> matchPin(String pin) async {
    return await BmoniSdkService.matchPin(pin);
  }

  @override
  Future<void> changePin({required String currentPin, required String newPin}) async {
    await BmoniSdkService.changePin(currentPin: currentPin, newPin: newPin);
  }

  @override
  Future<void> removePin(String currentPin) async {
    await BmoniSdkService.removePin(currentPin);
  }
}

/// StateNotifier coordinating on-device wallet lifecycle and UI states.
class WalletStateNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService;

  WalletStateNotifier(this._walletService) : super(const WalletState.noWallet()) {
    loadWalletState();
  }

  /// Refreshes and inspects device hardware state.
  Future<void> loadWalletState() async {
    try {
      final exists = await _walletService.hasWallet();
      if (!exists) {
        state = const WalletState.noWallet();
        return;
      }

      final address = await _walletService.getWalletAddress();
      final hasPin = await _walletService.hasPin();

      if (address != null) {
        state = WalletState.ready(address: address, hasPin: hasPin);
      } else {
        state = const WalletState.noWallet();
      }
    } catch (e) {
      state = WalletState.error(e.toString());
    }
  }

  /// Provisions a new on-device wallet and optionally sets PIN.
  Future<String?> createWallet({String? pin}) async {
    state = const WalletState.creating();
    try {
      final address = await _walletService.createWallet();
      if (pin != null && !await _walletService.hasPin()) {
        await _walletService.setPin(pin);
      }
      final hasPin = await _walletService.hasPin();
      state = WalletState.ready(address: address, hasPin: hasPin);
      return address;
    } on BmoniSignerException catch (e) {
      if (e.errorCode == BmoniSignerErrorCode.walletAlreadyExists) {
        final existingAddress = await _walletService.getWalletAddress();
        if (existingAddress != null) {
          final hasPin = await _walletService.hasPin();
          state = WalletState.ready(address: existingAddress, hasPin: hasPin);
          return existingAddress;
        }
      }
      state = WalletState.error('Provisioning failed: ${e.message}');
      return null;
    } catch (e) {
      state = WalletState.error('Failed to create wallet: $e');
      return null;
    }
  }

  /// Deletes the wallet from device storage and resets state.
  Future<bool> deleteWallet({String? pin}) async {
    try {
      await _walletService.deleteWallet(pin: pin);
      state = const WalletState.noWallet();
      return true;
    } on BmoniSignerException catch (e) {
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
  return const BmoniWalletService();
});

/// Riverpod provider for reactive [WalletState].
final walletStateProvider = StateNotifierProvider<WalletStateNotifier, WalletState>((ref) {
  final service = ref.watch(walletServiceProvider);
  return WalletStateNotifier(service);
});

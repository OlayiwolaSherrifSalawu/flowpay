import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../stellar/stellar_key_vault.dart';
import '../stellar/stellar_network.dart';

/// Thrown when a signing operation is cancelled by the user.
class SigningCancelledException implements Exception {
  final String message;
  const SigningCancelledException(
      [this.message = 'Signing was cancelled by the user.']);

  @override
  String toString() => 'SigningCancelledException: $message';
}

/// Abstract contract for on-device cryptographic signing.
///
/// 1. The Stellar secret key lives only on this device, encrypted under the PIN.
/// 2. It is never accessible to backend servers or AI models.
/// 3. Every signature requires the user's 6-digit PIN — there is no default.
abstract class WalletSigner {
  /// Signs a Stellar transaction envelope (base64 XDR) and returns the signed envelope.
  Future<String> signTransactionXdr(String envelopeXdr, {required String pin});

  /// ed25519 signature (hex) over the UTF-8 bytes of [message].
  /// Used for owner-proof and off-chain authorization.
  Future<String> signMessage(String message, {required String pin});

  /// ed25519 signature (hex) over raw bytes given as hex (e.g. a 32-byte hash).
  Future<String> signTransactionHash(String hashHex, {required String pin});
}

/// On-device Stellar signer backed by [StellarKeyVault].
class StellarWalletSigner implements WalletSigner {
  final StellarKeyVault? _vaultOverride;

  const StellarWalletSigner([this._vaultOverride]);

  StellarKeyVault get _vault => _vaultOverride ?? StellarKeyVault.instance;

  @override
  Future<String> signTransactionXdr(String envelopeXdr, {required String pin}) {
    return _vault.signTransactionXdr(
      envelopeXdr,
      pin: pin,
      networkPassphrase: StellarNetwork.current.passphrase,
    );
  }

  @override
  Future<String> signMessage(String message, {required String pin}) {
    return _vault.signBytes(Uint8List.fromList(utf8.encode(message)), pin: pin);
  }

  @override
  Future<String> signTransactionHash(String hashHex, {required String pin}) {
    final clean = hashHex.startsWith('0x') ? hashHex.substring(2) : hashHex;
    if (clean.isEmpty || clean.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw const StellarVaultException(StellarVaultErrorCode.signingFailed, 'Value to sign must be hex-encoded bytes.');
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < clean.length; i += 2) int.parse(clean.substring(i, i + 2), radix: 16),
    ]);
    return _vault.signBytes(bytes, pin: pin);
  }
}

/// Riverpod provider for the active [WalletSigner].
final walletSignerProvider = Provider<WalletSigner>((ref) {
  return const StellarWalletSigner();
});

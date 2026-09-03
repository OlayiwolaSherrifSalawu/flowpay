import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown when a signing operation is cancelled by the user.
class SigningCancelledException implements Exception {
  final String message;
  const SigningCancelledException([this.message = 'Signing was cancelled by the user.']);

  @override
  String toString() => 'SigningCancelledException: $message';
}

/// Abstract contract for on-device cryptographic signing.
///
/// Under BMONI B-Key architecture:
/// 1. Private keys reside strictly within hardware secure elements (Android Keystore / iOS Secure Enclave).
/// 2. Private keys are never accessible to FlowPay Dart code, backend servers, or AI models.
/// 3. Sensitive signing operations are gated by a user-configured 6-digit PIN.
abstract class WalletSigner {
  /// Signs an arbitrary UTF-8 message using EIP-191 personal_sign format.
  /// Used for login challenges, owner-proof verification, and off-chain authorization.
  Future<String> signMessage(String message, {String? pin});

  /// Signs a 32-byte pre-computed hash directly (no prefix).
  /// Used for ERC-4337 userOpHash, EIP-712 typed proposals, and transaction payloads.
  Future<String> signTransactionHash(String hashHex, {String? pin});
}

/// Official on-device BMONI B-Key signer implementation.
///
/// Directly delegates to `bmoni_embedded_sdk` on-device primitives.
/// Guarantees that no raw private keys, hashes, or PINs are ever logged or exposed.
class BmoniWalletSigner implements WalletSigner {
  const BmoniWalletSigner();

  @override
  Future<String> signMessage(String message, {String? pin}) async {
    try {
      return await BmoniEmbeddedSdk.signMessage(message, pin: pin);
    } on BmoniSignerException {
      rethrow;
    }
  }

  @override
  Future<String> signTransactionHash(String hashHex, {String? pin}) async {
    try {
      return await BmoniEmbeddedSdk.signTransactionHash(hashHex, pin: pin);
    } on BmoniSignerException {
      rethrow;
    }
  }
}

/// Riverpod provider for the active [WalletSigner].
final walletSignerProvider = Provider<WalletSigner>((ref) {
  return const BmoniWalletSigner();
});

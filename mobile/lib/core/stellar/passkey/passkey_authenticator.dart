import 'dart:typed_data';

import 'passkey_platform_stub.dart' if (dart.library.js_interop) 'passkey_platform_web.dart';

/// A passkey (WebAuthn credential with the PRF extension) that can derive a
/// secret only after the user verifies with Face ID / fingerprint / device PIN.
///
/// The vault uses that secret instead of the PIN to encrypt the wallet key, so a
/// copy of the encrypted key is useless without the passkey.
abstract class PasskeyAuthenticator {
  /// Whether this platform can create PRF passkeys (false on native and in tests).
  Future<bool> isSupported();

  /// Creates a passkey labelled [userName]; returns its credential ID (base64url).
  /// Throws [PasskeyException] if the user cancels or PRF isn't supported.
  Future<String> register({required String userName});

  /// Asks the user to verify, then returns the passkey's 32-byte PRF output for [salt].
  Future<Uint8List> prfSecret({required String credentialId, required Uint8List salt});

  /// The browser implementation on web; an unsupported stub elsewhere.
  factory PasskeyAuthenticator.platform() => createPlatformPasskeyAuthenticator();
}

class PasskeyException implements Exception {
  final String message;
  /// The user dismissed the prompt (not a wrong credential).
  final bool cancelled;
  const PasskeyException(this.message, {this.cancelled = false});

  @override
  String toString() => message;
}

/// Native platforms and tests: passkeys aren't offered (the PIN + OS keychain is used).
class UnsupportedPasskeyAuthenticator implements PasskeyAuthenticator {
  const UnsupportedPasskeyAuthenticator();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<String> register({required String userName}) =>
      throw const PasskeyException('Passkeys are not available on this device.');

  @override
  Future<Uint8List> prfSecret({required String credentialId, required Uint8List salt}) =>
      throw const PasskeyException('Passkeys are not available on this device.');
}

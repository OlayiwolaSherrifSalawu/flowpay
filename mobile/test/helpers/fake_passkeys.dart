import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flowpay_mobile/core/stellar/passkey/passkey_authenticator.dart';

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

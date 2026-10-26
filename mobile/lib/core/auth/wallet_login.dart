import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../network/api_client.dart';
import '../stellar/stellar_key_vault.dart';
import '../wallet/wallet_signer.dart';
import 'account_capabilities.dart';

class WalletLoginException implements Exception {
  final String message;
  const WalletLoginException(this.message);
  @override
  String toString() => message;
}

/// Signs in by proving control of this device's Stellar key (SEP-10 style):
/// the server issues a challenge, the PIN-unlocked key signs it, and the server
/// returns a session token. The PIN itself never leaves the device.
class WalletLogin {
  static Future<({UserProfile profile, String token})> signIn({required String pin, http.Client? client}) async {
    final httpClient = client ?? http.Client();
    final accountId = await StellarKeyVault.instance.publicKey();
    if (accountId == null) throw const WalletLoginException('There is no wallet on this device. Restore it with your recovery key.');

    Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
      final res = await httpClient
          .post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(FlowPayApiClient.requestTimeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw WalletLoginException(data['message']?.toString() ?? 'Sign in failed (${res.statusCode}).');
      }
      return data;
    }

    final challenge = await post('/api/auth/challenge', {'accountId': accountId});
    final message = (challenge['data'] as Map)['message'] as String;
    final signature = await const StellarWalletSigner().signMessage(message, pin: pin);
    final login = await post('/api/auth/login', {'accountId': accountId, 'message': message, 'signature': signature});

    final u = login['user'] as Map<String, dynamic>;
    final profile = UserProfile(
      userId: u['userId'] as String,
      fullName: u['fullName']?.toString() ?? '',
      email: u['email']?.toString() ?? '',
      phone: u['phone']?.toString() ?? '',
      country: u['country']?.toString() ?? 'US',
      accountType: u['accountType'] == 'business' ? AccountType.business : AccountType.personal,
      companyName: u['companyName']?.toString(),
      companyRole: u['companyRole']?.toString(),
      kycStatus: switch (u['kycStatus']) {
        'verified' => KycStatus.verified,
        'pending' => KycStatus.pending,
        _ => KycStatus.unverified,
      },
      createdAt: DateTime.now(),
    );
    final token = login['token'] as String;
    FlowPayApiClient.sessionToken = token;
    return (profile: profile, token: token);
  }
}

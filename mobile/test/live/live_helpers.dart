import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/network/api_client.dart';

/// A real FlowPay user created through the public signup endpoint.
class LiveUser {
  final String userId;
  final String token;
  const LiveUser(this.userId, this.token);

  /// Makes every FlowPayApiClient act as this user (the server reads identity
  /// only from the session token).
  void actAs() => FlowPayApiClient.sessionToken = token;
}

Future<LiveUser> liveSignup(String api, String name, String email, {String type = 'personal', String? company}) async {
  final res = await http.post(Uri.parse('$api/api/auth/signup'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'fullName': name, 'email': email, 'accountType': type, 'country': 'US', if (company != null) 'companyName': company}));
  final body = jsonDecode(res.body) as Map;
  if (res.statusCode != 201) throw StateError('signup failed: ${res.body}');
  final user = LiveUser((body['user'] as Map)['userId'] as String, body['token'] as String);
  user.actAs();
  return user;
}

/// Requires the backend to run with DEV_ECHO_EMAIL_CODES=true (never in production).
Future<void> liveVerifyEmail(String api, LiveUser user) async {
  final headers = {'content-type': 'application/json', 'authorization': 'Bearer ${user.token}'};
  final sent = jsonDecode((await http.post(Uri.parse('$api/api/auth/email/send'), headers: headers)).body) as Map;
  final code = (sent['data'] as Map)['devCode'] as String;
  final res = await http.post(Uri.parse('$api/api/auth/email/verify'), headers: headers, body: jsonEncode({'code': code}));
  if (res.statusCode != 200) throw StateError('verify failed: ${res.body}');
}

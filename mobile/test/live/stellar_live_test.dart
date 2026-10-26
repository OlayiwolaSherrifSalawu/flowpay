// Opt-in end-to-end check against Stellar TESTNET through a running FlowPay backend.
//
//   cd backend && npm run build && PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live
//
// Skipped by default so the normal suite never touches the network.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';

  test('device key → backend-built trustline tx → device signature → accepted by Horizon', () async {
    final accountId = await StellarKeyVault.instance.createWallet(pin: '123456');

    final fund = await http.post(Uri.parse('$api/api/stellar/accounts/$accountId/fund'));
    expect(fund.statusCode, 200, reason: fund.body);

    final build = await http.post(
      Uri.parse('$api/api/stellar/accounts/$accountId/trustlines'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'currencies': ['USD', 'NGN']}),
    );
    expect(build.statusCode, 200, reason: build.body);
    final unsignedXdr = (jsonDecode(build.body)['data'] as Map)['xdr'] as String;

    final signedXdr = await const StellarWalletSigner().signTransactionXdr(unsignedXdr, pin: '123456');

    final submit = await http.post(
      Uri.parse('$api/api/stellar/transactions'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'signedXdr': signedXdr}),
    );
    expect(submit.statusCode, 200, reason: submit.body);
    final data = jsonDecode(submit.body)['data'] as Map;
    expect(data['status'], 'COMPLETED');
    expect(data['hash'], matches(RegExp(r'^[0-9a-f]{64}$')));

    final summary = jsonDecode((await http.get(Uri.parse('$api/api/stellar/accounts/$accountId'))).body)['data'] as Map;
    expect(summary['missingTrustlines'], ['CAD', 'MXN', 'GBP']);
    // ignore: avoid_print
    print('LIVE OK account=$accountId tx=${data['explorerUrl']}');
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet');
}

// Opt-in: missions + FX conversion + locked savings on Stellar TESTNET.
//
//   cd backend && npm run build && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_missions_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/missions/mission_intent.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_mission_repo.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_wallet_repo.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_batch_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/stellar/stellar_network.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  test('FX convert to self, then a mission that converts + locks savings in one transaction', () async {
    final signupRes = await http.post(Uri.parse('$api/api/auth/signup'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'fullName': 'Mira Live $stamp', 'email': 'mira.$stamp@flowpay.test', 'accountType': 'personal', 'country': 'US'}));
    final body = jsonDecode(signupRes.body) as Map;
    final userId = ((body['user'] ?? body['data']?['user'] ?? body['data']) as Map)['userId'] as String;

    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    final accountId = await StellarKeyVault.instance.createWallet(pin: '123456');
    final client = FlowPayApiClient(baseUrl: api, userId: userId);
    final report = await StellarActivation(api: StellarApi(client)).activate(pin: '123456');
    expect(report.isActive, isTrue, reason: report.failures.map((f) => f.error).join('\n'));

    // 1) Convert exactly $100 → MXN, to myself.
    final batch = StellarBatchApi(client);
    final fx = await batch.propose(legs: [
      {'label': 'USD→MXN', 'to': 'self', 'mode': 'exact_send', 'amount': {'amountMinor': '10000', 'currency': 'USD'}, 'destCurrency': 'MXN'},
    ], purpose: 'FX_CONVERT');
    final fxDone = await batch.execute(
      proposalId: fx.proposalId,
      signedXdr: await const StellarWalletSigner().signTransactionXdr(fx.signPayload, pin: '123456'),
    );
    expect(fxDone.status, 'COMPLETED');
    // ignore: avoid_print
    print('LIVE FX → ${fxDone.explorerUrl}');
    final mxn = (await StellarWalletRepository(apiClient: client).getWallets()).firstWhere((w) => w.currency == Currency.mxn).balance;
    expect(mxn.majorUnits, greaterThan(1700), reason: '\$100 ≈ Mex\$1,750 minus pool fee');

    // 2) Mission: $200 → 50% NGN, 50% locked USD savings (30 days).
    final missions = StellarMissionRepository(apiClient: client);
    final intent = MissionIntent.fromJson({
      'intentId': 'live_$stamp',
      'originalPrompt': 'split 200',
      'intentType': 'SPLIT_INCOMING',
      'ruleTitle': 'Live split',
      'triggerCondition': {'type': 'MANUAL', 'sourceCurrency': 'USD', 'sourceAmount': '200.00', 'sourceAmountMinor': '20000', 'description': 'Manual'},
      'allocations': [
        {'id': 'a1', 'category': 'EXPENSES', 'label': 'Naira', 'percentage': 50, 'targetCurrency': 'NGN', 'sourceAmountMinor': '10000', 'sourceAmountFormatted': '\$100.00', 'destinationWalletTag': 'NGN', 'actionType': 'CONVERT_FX'},
        {'id': 'a2', 'category': 'SAVINGS', 'label': 'Savings', 'percentage': 50, 'targetCurrency': 'USD', 'sourceAmountMinor': '10000', 'sourceAmountFormatted': '\$100.00', 'destinationWalletTag': 'Vault', 'actionType': 'SWEEP_VAULT'},
      ],
      'destinationWallets': <String, String>{},
      'explanation': 'live',
      'confidenceScore': 1,
      'requiresExplicitApproval': true,
    });
    final run = await missions.proposeMission(intent);
    expect(run.movesMoney, isTrue);
    final result = await missions.executeMission(
      missionId: run.missionId,
      proposalId: run.proposalId,
      signedPayload: await const StellarWalletSigner().signTransactionXdr(run.signPayload!, pin: '123456'),
    );
    expect(result['status'], 'ACTIVE');
    // ignore: avoid_print
    print('LIVE mission → ${result['explorerUrl']}');

    final listed = (await missions.getMissions()).single;
    expect(listed.executionCount, 1);

    // The locked savings exist on-chain, claimable only by me, only later.
    final cb = jsonDecode((await http.get(Uri.parse('${StellarNetwork.testnet.horizonUrl}/claimable_balances?claimant=$accountId'))).body);
    final records = (cb['_embedded']['records'] as List);
    expect(records, hasLength(1));
    expect(records.single['amount'], '100.0000000');
    expect(records.single['claimants'].single['destination'], accountId);
    expect(records.single['claimants'].single['predicate'].containsKey('not'), isTrue);
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 3)));
}

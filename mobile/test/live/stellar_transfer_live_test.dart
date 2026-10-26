// Opt-in end-to-end money movement on Stellar TESTNET through a running FlowPay backend.
//
//   cd backend && npm run build && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_transfer_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_transfer_repo.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_wallet_repo.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/transfers/transfer_intent.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  Future<String> signup(String name, String email) async {
    final res = await http.post(Uri.parse('$api/api/auth/signup'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'fullName': name, 'email': email, 'accountType': 'personal', 'country': 'US'}));
    expect(res.statusCode, anyOf(200, 201), reason: res.body);
    final body = jsonDecode(res.body) as Map;
    return ((body['user'] ?? body['data']?['user'] ?? body['data']) as Map)['userId'] as String;
  }

  /// Each user = their own device vault; swap the global vault to "switch phones".
  Future<({String userId, String accountId, StellarKeyVault vault})> onboard(String name, String email) async {
    final userId = await signup(name, email);
    final vault = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    StellarKeyVault.instance = vault;
    final accountId = await vault.createWallet(pin: '123456');
    final report = await StellarActivation(api: StellarApi(FlowPayApiClient(baseUrl: api, userId: userId))).activate(pin: '123456');
    expect(report.isActive, isTrue, reason: report.failures.map((f) => '${f.step}: ${f.error}').join('\n'));
    return (userId: userId, accountId: accountId, vault: vault);
  }

  test('two users: activate, send USD by email, send NGN funded from USD via path payment', () async {
    final alice = await onboard('Alice Live $stamp', 'alice.$stamp@flowpay.test');
    final bob = await onboard('Bob Live $stamp', 'bob.$stamp@flowpay.test');

    // Act as Alice.
    StellarKeyVault.instance = alice.vault;
    final client = FlowPayApiClient(baseUrl: api, userId: alice.userId);
    final transfers = StellarTransferRepository(apiClient: client);
    final wallets = StellarWalletRepository(apiClient: client);

    final usdBefore = (await wallets.getWallets()).firstWhere((w) => w.currency == Currency.usd).balance;
    expect(usdBefore.minorUnits, 100000, reason: 'activation claimed 1,000 test USD');

    Future<String> send(String amount, Currency currency, {Currency? fundFrom}) async {
      final intent = TransferIntent(
        intentId: 'live_${DateTime.now().microsecondsSinceEpoch}',
        originalPrompt: 'live test',
        recipient: 'bob.$stamp@flowpay.test',
        amount: amount,
        amountMinor: (double.parse(amount) * 100).round().toString(),
        currency: currency,
        purpose: 'Live test',
        confidenceScore: 1,
        requiresExplicitApproval: true,
      );
      final inspection = await transfers.inspectBalances(intent: intent, wallets: const []);
      expect(inspection.isPossible, isTrue, reason: inspection.reason);
      final option = inspection.allFundingOptions.firstWhere((o) => o.fundingCurrency == (fundFrom ?? currency));
      final proposal = await transfers.createProposal(intent: intent, fundingOption: option);
      final signed = await const StellarWalletSigner().signTransactionXdr(proposal.signPayload, pin: '123456');
      final result = await transfers.executeProposal(proposalId: proposal.proposalId, signature: signed, proposal: proposal);
      expect(result.status, 'COMPLETED');
      expect(result.transactionHash, proposal.proposalId);
      // ignore: avoid_print
      print('LIVE $amount ${currency.code} (from ${(fundFrom ?? currency).code}) → ${result.explorerUrl}');
      return result.transactionHash;
    }

    await send('25.00', Currency.usd);
    await send('10000.00', Currency.ngn, fundFrom: Currency.usd);

    // Bob's balances, read from the network as Bob.
    StellarKeyVault.instance = bob.vault;
    final bobWallets = await StellarWalletRepository(apiClient: FlowPayApiClient(baseUrl: api, userId: bob.userId)).getWallets();
    final bobUsd = bobWallets.firstWhere((w) => w.currency == Currency.usd).balance.minorUnits;
    final bobNgn = bobWallets.firstWhere((w) => w.currency == Currency.ngn).balance.minorUnits;
    expect(bobUsd, 100000 + 2500);
    expect(bobNgn, 1000000);

    // Alice paid 25 USD + ~6.47 USD for ₦10,000 (≈ 10000/1550 plus pool fee), never more than the sendMax.
    StellarKeyVault.instance = alice.vault;
    final usdAfter = (await wallets.getWallets()).firstWhere((w) => w.currency == Currency.usd).balance.minorUnits;
    final spent = 100000 - usdAfter;
    expect(spent, inInclusiveRange(2500 + 640, 2500 + 660));

    final history = await StellarApi(client).payments(alice.accountId);
    expect(history.where((p) => p.direction == 'outgoing' && p.counterparty == bob.accountId).length, 2);
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 3)));
}

// Opt-in: one employer pays employees in NG, MX and GB in ONE Stellar transaction.
//
//   cd backend && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none SMTP_HOST=127.0.0.1 SMTP_PORT=1 PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_payroll_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/navigation/invite_link.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_employee_repo.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_payroll_repo.dart';
import 'package:flowpay_mobile/core/state/business_provider.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  Future<String> signup(String name, String email, String type) async {
    final res = await http.post(Uri.parse('$api/api/auth/signup'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'fullName': name, 'email': email, 'accountType': type, 'country': 'US', 'companyName': 'Payroll Co $stamp'}));
    final body = jsonDecode(res.body) as Map;
    return ((body['user'] ?? body['data']?['user'] ?? body['data']) as Map)['userId'] as String;
  }

  Future<({StellarKeyVault vault, String account})> activate(String userId, {bool testFunds = false}) async {
    final vault = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    StellarKeyVault.instance = vault;
    final account = await vault.createWallet(pin: '123456');
    final r = await StellarActivation(api: StellarApi(FlowPayApiClient(baseUrl: api, userId: userId))).activate(pin: '123456', claimTestFunds: testFunds);
    expect(r.isActive, isTrue, reason: r.failures.map((f) => f.error).join('\n'));
    return (vault: vault, account: account);
  }

  test('employer pays NG, MX and GB employees in one atomic transaction', () async {
    final bossId = await signup('Boss $stamp', 'boss.$stamp@flowpay.test', 'business');
    final boss = await activate(bossId, testFunds: true); // $1,000 test USD
    final bossClient = FlowPayApiClient(baseUrl: api, userId: bossId);
    final employees = StellarEmployeeRepository(apiClient: bossClient);

    final team = {
      'NG': (Currency.ngn, '150000.00'),
      'MX': (Currency.mxn, '1750.00'),
      'GB': (Currency.gbp, '78.00'),
    };
    final accounts = <String, String>{};
    for (final entry in team.entries) {
      final email = '${entry.key.toLowerCase()}.$stamp@flowpay.test';
      final url = await employees.createEmployee(
        firstName: 'Emp${entry.key}',
        lastName: 'Live',
        email: email,
        country: entry.key,
        targetCurrency: entry.value.$1,
        payrollAmount: Money.fromMajorString(entry.value.$2, entry.value.$1),
      );
      final empId = await signup('Emp${entry.key} Live', email, 'personal');
      final w = await activate(empId);
      accounts[entry.key] = w.account;
      await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api, userId: empId)).acceptInvite(InviteLink.parse(url)!);
    }

    // The employer previews, signs once (one batch), and submits.
    StellarKeyVault.instance = boss.vault;
    final payroll = StellarPayrollRepository(apiClient: bossClient);
    final preview = await payroll.getPayrollPreview();
    expect(preview.items.where((i) => i.status == 'PENDING').length, 3);
    expect(preview.batches, hasLength(1));
    expect(preview.isBalanceSufficient, isTrue);

    final signed = await BusinessProvider.signPayrollBatches(preview, '123456');
    final done = await payroll.executePayrollRun(runId: preview.runId, signedBatches: signed);
    expect(done.status, 'COMPLETED');
    final hash = done.batches.single.transactionHash!;
    expect(done.items.every((i) => i.transactionHash == hash), isTrue);
    // ignore: avoid_print
    print('LIVE payroll → ${done.batches.single.explorerUrl}  (USD ${done.totalUsd.toMajorString()})');

    final stellar = StellarApi(bossClient);
    for (final entry in team.entries) {
      final s = await stellar.account(accounts[entry.key]!);
      final bal = s.balances.firstWhere((b) => b.currency == entry.value.$1).amount;
      expect(bal.toMajorString(), entry.value.$2, reason: '${entry.key} received exactly their salary');
    }
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 4)));
}

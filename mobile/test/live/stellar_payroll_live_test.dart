// Opt-in: one employer pays employees in NG, MX and GB in ONE Stellar transaction.
//
//   cd backend && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none SMTP_HOST=127.0.0.1 SMTP_PORT=1 DEV_ECHO_EMAIL_CODES=true PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_payroll_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
import 'live_helpers.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  Future<({StellarKeyVault vault, String account})> activate(LiveUser user, {bool testFunds = false}) async {
    user.actAs();
    final vault = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    StellarKeyVault.instance = vault;
    final account = await vault.createWallet(pin: '123456');
    final r = await StellarActivation(api: StellarApi(FlowPayApiClient(baseUrl: api))).activate(pin: '123456', claimTestFunds: testFunds);
    expect(r.isActive, isTrue, reason: r.failures.map((f) => f.error).join('\n'));
    return (vault: vault, account: account);
  }

  test('employer pays NG, MX and GB employees in one atomic transaction', () async {
    final bossUser = await liveSignup(api, 'Boss $stamp', 'boss.$stamp@flowpay.test', type: 'business', company: 'Payroll Co');
    final boss = await activate(bossUser, testFunds: true); // $1,000 test USD
    final bossClient = FlowPayApiClient(baseUrl: api);
    final employees = StellarEmployeeRepository(apiClient: bossClient);

    final team = {
      'NG': (Currency.ngn, '150000.00'),
      'MX': (Currency.mxn, '1750.00'),
      'GB': (Currency.gbp, '78.00'),
    };
    final accounts = <String, String>{};
    for (final entry in team.entries) {
      final email = '${entry.key.toLowerCase()}.$stamp@flowpay.test';
      bossUser.actAs();
      final url = await employees.createEmployee(
        firstName: 'Emp${entry.key}',
        lastName: 'Live',
        email: email,
        country: entry.key,
        targetCurrency: entry.value.$1,
        payrollAmount: Money.fromMajorString(entry.value.$2, entry.value.$1),
      );
      final emp = await liveSignup(api, 'Emp${entry.key} Live', email);
      final w = await activate(emp);
      accounts[entry.key] = w.account;
      await liveVerifyEmail(api, emp);
      await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).acceptInvite(InviteLink.parse(url)!);
    }

    // The employer previews, signs once (one batch), and submits.
    StellarKeyVault.instance = boss.vault;
    bossUser.actAs();
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

// Opt-in: Soroban payday guarantee on TESTNET — lock, refuse early claim, claim + release on payday.
//
//   cd backend && npm run build && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none SMTP_HOST=127.0.0.1 SMTP_PORT=1 DEV_ECHO_EMAIL_CODES=true PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_guarantee_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/navigation/invite_link.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_employee_repo.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_payroll_repo.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/wallet/wallet_signer.dart';
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

  Future<double> usdBalance(String account) async {
    final s = await StellarApi(FlowPayApiClient(baseUrl: api)).account(account);
    return s.balances.firstWhere((b) => b.currency == Currency.usd).amount.majorUnits.toDouble();
  }

  test('employer locks payday on Soroban; early claim refused; claim + release on payday', () async {
    final bossUser = await liveSignup(api, 'Boss $stamp', 'gboss.$stamp@flowpay.test', type: 'business', company: 'Guarantee Co');
    final boss = await activate(bossUser, testFunds: true);
    final team = <String, ({LiveUser user, StellarKeyVault vault, String account})>{};
    for (final (first, country, currency, amount) in [('Ada', 'NG', Currency.ngn, '15500.00'), ('Mateo', 'MX', Currency.mxn, '175.00')]) {
      final email = '${first.toLowerCase()}.g.$stamp@flowpay.test';
      bossUser.actAs();
      final url = await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).createEmployee(
        firstName: first, lastName: 'Live', email: email, country: country, targetCurrency: currency,
        payrollAmount: Money.fromMajorString(amount, currency),
      );
      final emp = await liveSignup(api, '$first Live', email);
      final w = await activate(emp);
      await liveVerifyEmail(api, emp);
      await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).acceptInvite(InviteLink.parse(url)!);
      team[first] = (user: emp, vault: w.vault, account: w.account);
    }

    // 1) Employer locks payday ~75 s from now, signing the contract call on device.
    bossUser.actAs();
    StellarKeyVault.instance = boss.vault;
    final repo = StellarPayrollRepository(apiClient: FlowPayApiClient(baseUrl: api));
    final payday = DateTime.now().add(const Duration(seconds: 75));
    final proposal = await repo.proposeGuarantee(payday);
    expect(proposal.entries, hasLength(2));
    final bossUsdBefore = await usdBalance(boss.account);
    final g = await repo.executeGuarantee(
      proposalId: proposal.proposalId,
      signedPayload: await const StellarWalletSigner().signTransactionXdr(proposal.signPayload!, pin: '123456'),
    );
    // ignore: avoid_print
    print('LIVE guarantee funded → ${g.explorerUrl}  (\$${g.totalUsd}, id ${g.payrollId})');
    expect((await usdBalance(boss.account)), closeTo(bossUsdBefore - double.parse(g.totalUsd), 0.0001));
    final listed = (await repo.getGuarantees()).single;
    expect(listed.remainingUsd, g.totalUsd);
    expect(listed.isUnlocked, isFalse);

    // 2) Ada sees her pay is reserved, but can't claim before payday (contract refuses at simulation).
    final ada = team['Ada']!;
    ada.user.actAs();
    StellarKeyVault.instance = ada.vault;
    final adaRepo = StellarPayrollRepository(apiClient: FlowPayApiClient(baseUrl: api));
    final mine = (await adaRepo.getMyGuaranteedPay()).single;
    expect(mine.paid, isFalse);
    expect(mine.coversFormatted, contains('NGN'));
    await expectLater(adaRepo.proposeGuaranteeClaim(g.payrollId), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains("isn't payday yet"))));

    // 3) Payday: Ada claims hers; the employer releases the rest.
    final wait = payday.difference(DateTime.now()) + const Duration(seconds: 15);
    if (!wait.isNegative) await Future.delayed(wait);
    final adaBefore = await usdBalance(ada.account);
    final claim = await adaRepo.proposeGuaranteeClaim(g.payrollId);
    final claimed = await adaRepo.executeGuaranteeClaim(
      proposalId: claim.proposalId,
      signedPayload: await const StellarWalletSigner().signTransactionXdr(claim.signPayload!, pin: '123456'),
    );
    // ignore: avoid_print
    print('LIVE claim → ${claimed.explorerUrl}  (\$${claimed.amountUsd})');
    expect(claimed.status, 'COMPLETED');
    expect(await usdBalance(ada.account), closeTo(adaBefore + double.parse(mine.amountUsd), 0.0001));

    bossUser.actAs();
    final mateo = team['Mateo']!;
    final mateoBefore = await usdBalance(mateo.account);
    final released = await repo.releaseGuarantee(g.payrollId);
    // ignore: avoid_print
    print('LIVE release → ${released.map((r) => '${r.name}: ${r.status} ${r.explorerUrl ?? ''}').join(' | ')}');
    expect(released.firstWhere((r) => r.name.startsWith('Ada')).status, 'ALREADY_PAID');
    expect(released.firstWhere((r) => r.name.startsWith('Mateo')).status, 'COMPLETED');
    final mateoEntry = g.entries.firstWhere((e) => e.name.startsWith('Mateo'));
    expect(await usdBalance(mateo.account), closeTo(mateoBefore + double.parse(mateoEntry.amountUsd), 0.0001));

    final after = (await repo.getGuarantees()).single;
    expect(after.remainingUsd, '0.00');
    expect(after.isFullyPaid, isTrue);
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 6)));
}

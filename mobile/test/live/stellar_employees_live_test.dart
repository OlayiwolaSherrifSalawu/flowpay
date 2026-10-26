// Opt-in: employer invites → employee creates own wallet on testnet → verifies email → accepts.
//
//   cd backend && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none SMTP_HOST=127.0.0.1 SMTP_PORT=1 DEV_ECHO_EMAIL_CODES=true PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_employees_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/navigation/invite_link.dart';
import 'package:flowpay_mobile/core/network/api_client.dart';
import 'package:flowpay_mobile/core/providers/stellar/stellar_employee_repo.dart';
import 'package:flowpay_mobile/core/repositories/employee_repository.dart';
import 'package:flowpay_mobile/core/stellar/stellar_activation.dart';
import 'package:flowpay_mobile/core/stellar/stellar_api.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'live_helpers.dart';

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  Future<String> activateWallet(LiveUser user) async {
    user.actAs();
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    final account = await StellarKeyVault.instance.createWallet(pin: '123456');
    final report = await StellarActivation(api: StellarApi(FlowPayApiClient(baseUrl: api))).activate(pin: '123456', claimTestFunds: false);
    expect(report.isActive, isTrue, reason: report.failures.map((f) => f.error).join('\n'));
    return account;
  }

  test('employer invites; impostor refused; employee verifies email and joins with own wallet', () async {
    // Unauthenticated calls are refused outright.
    expect((await http.get(Uri.parse('$api/api/employees'), headers: {'x-user-id': 'usr_anyone'})).statusCode, 401);

    final boss = await liveSignup(api, 'Boss $stamp', 'boss.$stamp@flowpay.test', type: 'business', company: 'Live Corp');
    final employer = StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api));
    final inviteUrl = await employer.createEmployee(
      firstName: 'Ngozi',
      lastName: 'Live',
      email: 'ngozi.$stamp@flowpay.test',
      country: 'NG',
      targetCurrency: Currency.ngn,
      payrollAmount: Money.fromMajorString('750000.00', Currency.ngn),
    );
    final token = InviteLink.parse(inviteUrl)!;
    expect((await employer.getEmployees()).single.status, EmployeeLifecycleStages.invited);
    expect((await http.get(Uri.parse('$api/api/employees/invite/ngozi.$stamp@flowpay.test'))).statusCode, 404);

    final imposter = await liveSignup(api, 'Imposter $stamp', 'x.$stamp@flowpay.test');
    await activateWallet(imposter);
    await liveVerifyEmail(api, imposter);
    await expectLater(
      StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).acceptInvite(token),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );

    final ngozi = await liveSignup(api, 'Ngozi Live', 'ngozi.$stamp@flowpay.test');
    final account = await activateWallet(ngozi);
    await expectLater(
      StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).acceptInvite(token),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')),
    );
    await liveVerifyEmail(api, ngozi);
    final joined = await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api)).acceptInvite(token);
    expect(joined.status, EmployeeLifecycleStages.ready);
    expect(joined.walletAddress, account);

    boss.actAs();
    expect((await employer.getEmployees()).single.walletAddress, account);
    // ignore: avoid_print
    print('LIVE employee $account joined');
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 3)));
}

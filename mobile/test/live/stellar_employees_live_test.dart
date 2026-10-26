// Opt-in: employer invites → employee creates own wallet on testnet → accepts.
//
//   cd backend && DATABASE_URL=postgresql://none:none@127.0.0.1:1/none SMTP_HOST=127.0.0.1 SMTP_PORT=1 PORT=4099 node dist/server.js &
//   cd mobile && LIVE_STELLAR=1 FLOWPAY_API=http://localhost:4099 flutter test test/live/stellar_employees_live_test.dart
import 'dart:convert';
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

void main() {
  final enabled = Platform.environment['LIVE_STELLAR'] == '1';
  final api = Platform.environment['FLOWPAY_API'] ?? 'http://localhost:4099';
  final stamp = DateTime.now().millisecondsSinceEpoch;

  Future<String> signup(String name, String email, String type) async {
    final res = await http.post(Uri.parse('$api/api/auth/signup'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'fullName': name, 'email': email, 'accountType': type, 'country': 'US', 'companyName': 'Live Corp $stamp'}));
    final body = jsonDecode(res.body) as Map;
    return ((body['user'] ?? body['data']?['user'] ?? body['data']) as Map)['userId'] as String;
  }

  Future<String> activateWallet(String userId) async {
    StellarKeyVault.instance = StellarKeyVault(store: InMemoryVaultStore(), kdfIterations: 1000);
    final account = await StellarKeyVault.instance.createWallet(pin: '123456');
    final report = await StellarActivation(api: StellarApi(FlowPayApiClient(baseUrl: api, userId: userId)))
        .activate(pin: '123456', claimTestFunds: false);
    expect(report.isActive, isTrue, reason: report.failures.map((f) => f.error).join('\n'));
    return account;
  }

  test('employer invites; impostor is refused; employee joins with their own wallet', () async {
    final employerId = await signup('Boss $stamp', 'boss.$stamp@flowpay.test', 'business');
    final employer = StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api, userId: employerId));
    final inviteUrl = await employer.createEmployee(
      firstName: 'Ngozi',
      lastName: 'Live',
      email: 'ngozi.$stamp@flowpay.test',
      country: 'NG',
      targetCurrency: Currency.ngn,
      payrollAmount: Money.fromMajorString('750000.00', Currency.ngn),
    );
    final token = InviteLink.parse(inviteUrl)!;
    final roster = await employer.getEmployees();
    expect(roster.single.status, EmployeeLifecycleStages.invited);

    // Invites resolve by token only.
    final byEmail = await http.get(Uri.parse('$api/api/employees/invite/ngozi.$stamp@flowpay.test'));
    expect(byEmail.statusCode, 404);

    // Someone else with a proven wallet can't take it.
    final imposterId = await signup('Imposter $stamp', 'x.$stamp@flowpay.test', 'personal');
    await activateWallet(imposterId);
    await expectLater(
      StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api, userId: imposterId)).acceptInvite(token),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );

    // The real employee: own device, own wallet, same email.
    final employeeId = await signup('Ngozi Live', 'ngozi.$stamp@flowpay.test', 'personal');
    final employeeAccount = await activateWallet(employeeId);
    final joined = await StellarEmployeeRepository(apiClient: FlowPayApiClient(baseUrl: api, userId: employeeId)).acceptInvite(token);
    expect(joined.status, EmployeeLifecycleStages.ready);
    expect(joined.walletAddress, employeeAccount);

    final after = (await employer.getEmployees()).single;
    expect(after.walletAddress, employeeAccount);
    // ignore: avoid_print
    print('LIVE employee $employeeAccount joined ${roster.single.id}');
  }, skip: enabled ? false : 'set LIVE_STELLAR=1 to run against testnet', timeout: const Timeout(Duration(minutes: 3)));
}

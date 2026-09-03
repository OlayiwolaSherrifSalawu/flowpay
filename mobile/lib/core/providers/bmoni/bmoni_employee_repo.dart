import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/employee_repository.dart';

class BmoniEmployeeRepository implements EmployeeRepository {
  final FlowPayApiClient apiClient;

  BmoniEmployeeRepository({required this.apiClient});

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    final res = await apiClient.get('/api/employees');
    if (res is List) {
      return res.map((e) {
        final targetCurr = Currency.fromCode(e['target_currency'] ?? 'USD');
        return EmployeeModel(
          id: e['id'] ?? '',
          bmoniUserId: e['bmoni_user_id'],
          firstName: e['first_name'] ?? '',
          lastName: e['last_name'] ?? '',
          email: e['email'] ?? '',
          phoneNumber: e['phone_number'],
          country: e['country'] ?? 'NG',
          countryName: e['country_name'] ?? '',
          targetCurrency: targetCurr,
          status: e['status'] ?? 'ACTIVE',
          onboardingStatus: e['onboarding_status'] ?? 'ONBOARDED',
          walletStatus: e['wallet_status'] ?? 'PROVISIONED',
          cardStatus: e['card_status'] ?? 'ACTIVE',
          payrollAmount: e['payroll_amount'] != null
              ? Money.fromMinor(e['payroll_amount'] as int, targetCurr)
              : null,
          usdPayrollAmount: e['usd_payroll_amount'] != null
              ? Money.fromMinor(e['usd_payroll_amount'] as int, Currency.usd)
              : null,
          walletAddress: e['wallet_address'],
          cardId: e['card_id'],
          cardLast4: e['card_last4'] ?? '4289',
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    final res = await apiClient.get('/api/employees/$id');
    final targetCurr = Currency.fromCode(res['target_currency'] ?? 'USD');
    return EmployeeModel(
      id: res['id'] ?? id,
      bmoniUserId: res['bmoni_user_id'],
      firstName: res['first_name'] ?? '',
      lastName: res['last_name'] ?? '',
      email: res['email'] ?? '',
      phoneNumber: res['phone_number'],
      country: res['country'] ?? 'NG',
      countryName: res['country_name'] ?? '',
      targetCurrency: targetCurr,
      status: res['status'] ?? 'ACTIVE',
      onboardingStatus: res['onboarding_status'] ?? 'ONBOARDED',
      walletStatus: res['wallet_status'] ?? 'PROVISIONED',
      cardStatus: res['card_status'] ?? 'ACTIVE',
      payrollAmount: res['payroll_amount'] != null
          ? Money.fromMinor(res['payroll_amount'] as int, targetCurr)
          : null,
      usdPayrollAmount: res['usd_payroll_amount'] != null
          ? Money.fromMinor(res['usd_payroll_amount'] as int, Currency.usd)
          : null,
      walletAddress: res['wallet_address'],
      cardId: res['card_id'],
      cardLast4: res['card_last4'] ?? '4289',
    );
  }

  @override
  Future<String> inviteEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    Money? payrollAmount,
    Money? usdPayrollAmount,
  }) async {
    final res = await apiClient.post('/api/employees/invite', body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'country': country,
      'countryName': countryName,
      'targetCurrency': targetCurrency.code,
      if (payrollAmount != null) 'payrollAmount': payrollAmount.minorUnits,
      if (usdPayrollAmount != null) 'usdPayrollAmount': usdPayrollAmount.minorUnits,
    });
    return res['inviteUrl'] ?? 'https://bmoni.com/invite';
  }
}

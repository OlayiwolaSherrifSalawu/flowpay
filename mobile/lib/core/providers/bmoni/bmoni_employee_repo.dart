import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/employee_repository.dart';

class BmoniEmployeeRepository implements EmployeeRepository {
  final FlowPayApiClient apiClient;

  BmoniEmployeeRepository({required this.apiClient});

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      final res = await apiClient.get('/api/employees');
      final list = (res is Map && res['data'] is List)
          ? res['data'] as List
          : (res is List ? res : []);

      return list.map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    final res = await apiClient.get('/api/employees/$id');
    final data = (res is Map && res['data'] is Map)
        ? res['data'] as Map<String, dynamic>
        : (res as Map<String, dynamic>);
    return EmployeeModel.fromJson(data);
  }

  @override
  Future<String> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    required Money payrollAmount,
    Money? usdPayrollAmount,
  }) async {
    final res = await apiClient.post('/api/employees', body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      'country': country,
      if (countryName != null) 'countryName': countryName,
      'targetCurrency': targetCurrency.code,
      'payrollAmountMinor': payrollAmount.minorUnits,
      if (usdPayrollAmount != null) 'usdPayrollAmountMinor': usdPayrollAmount.minorUnits,
    });

    return res['inviteUrl'] ??
        res['data']?['employee']?['id'] ??
        'https://bmoni.com/invite';
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
  }) {
    return createEmployee(
      firstName: firstName,
      lastName: lastName,
      email: email,
      country: country,
      countryName: countryName,
      targetCurrency: targetCurrency,
      payrollAmount: payrollAmount ?? Money.fromMajorString('2000.00', targetCurrency),
      usdPayrollAmount: usdPayrollAmount,
    );
  }
}

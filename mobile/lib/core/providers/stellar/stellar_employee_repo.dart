import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/employee_repository.dart';

/// Live employees: the employer's roster on the FlowPay backend. Employees join by
/// accepting an invite with a Stellar wallet they created and proved on their own
/// device. Errors propagate.
class StellarEmployeeRepository implements EmployeeRepository {
  final FlowPayApiClient apiClient;

  StellarEmployeeRepository({required this.apiClient});

  Map<String, String> get _identity => {'x-user-id': apiClient.userId};

  static List<dynamic> _items(dynamic res) {
    if (res is List) return res;
    if (res is Map && res['items'] is List) return res['items'] as List;
    return const [];
  }

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    final res = await apiClient.get('/api/employees', headers: _identity);
    return [for (final e in _items(res)) EmployeeModel.fromJson(Map<String, dynamic>.from(e as Map))];
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    final res = await apiClient.get('/api/employees/$id', headers: _identity);
    return EmployeeModel.fromJson(Map<String, dynamic>.from(res as Map));
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
    final res = Map<String, dynamic>.from(await apiClient.post('/api/employees', headers: _identity, body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      'country': country,
      'targetCurrency': targetCurrency.code,
      'payrollAmountMinor': payrollAmount.minorUnits,
    }) as Map);
    final url = res['inviteUrl']?.toString();
    if (url == null || url.isEmpty) throw StateError('The server did not return an invite link.');
    return url;
  }

  @override
  Future<String> resendInvite(String employeeId) async {
    final res = await apiClient.post('/api/employees/$employeeId/resend-invite', headers: _identity);
    return (res as Map)['inviteUrl'].toString();
  }

  @override
  Future<Map<String, dynamic>> getInviteDetails(String token) async {
    return Map<String, dynamic>.from(await apiClient.get('/api/employees/invite/$token') as Map);
  }

  @override
  Future<EmployeeModel> acceptInvite(String token) async {
    final res = await apiClient.post('/api/employees/invite/$token/accept', headers: _identity);
    return EmployeeModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<EmployeeModel> setEmployeeStatus(String employeeId, String status) async {
    final res = await apiClient.patch('/api/employees/$employeeId', headers: _identity, body: {'status': status});
    return EmployeeModel.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

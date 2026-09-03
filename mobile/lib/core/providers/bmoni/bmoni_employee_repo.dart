import '../../money/currency.dart';
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
        return EmployeeModel(
          id: e['id'] ?? '',
          bmoniUserId: e['bmoni_user_id'],
          firstName: e['first_name'] ?? '',
          lastName: e['last_name'] ?? '',
          email: e['email'] ?? '',
          phoneNumber: e['phone_number'],
          country: e['country'] ?? 'NG',
          targetCurrency: Currency.fromCode(e['target_currency'] ?? 'USD'),
          status: e['status'] ?? 'INVITED',
          walletAddress: e['wallet_address'],
          cardId: e['card_id'],
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    final res = await apiClient.get('/api/employees/$id');
    return EmployeeModel(
      id: res['id'] ?? id,
      bmoniUserId: res['bmoni_user_id'],
      firstName: res['first_name'] ?? '',
      lastName: res['last_name'] ?? '',
      email: res['email'] ?? '',
      phoneNumber: res['phone_number'],
      country: res['country'] ?? 'NG',
      targetCurrency: Currency.fromCode(res['target_currency'] ?? 'USD'),
      status: res['status'] ?? 'INVITED',
      walletAddress: res['wallet_address'],
      cardId: res['card_id'],
    );
  }

  @override
  Future<String> inviteEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String country,
    required Currency targetCurrency,
  }) async {
    final res = await apiClient.post('/api/employees/invite', body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'country': country,
      'targetCurrency': targetCurrency.code,
    });
    return res['inviteUrl'] ?? 'https://bmoni.com/invite';
  }
}

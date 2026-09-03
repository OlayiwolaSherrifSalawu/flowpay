import '../../money/currency.dart';
import '../../repositories/employee_repository.dart';
import 'demo_data.dart';

class DemoEmployeeRepository implements EmployeeRepository {
  final List<EmployeeModel> _employees = List.from(DemoData.employees);

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _employees;
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _employees.firstWhere(
      (e) => e.id == id,
      orElse: () => _employees.first,
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
    await Future.delayed(const Duration(milliseconds: 300));
    final newId = 'emp_demo_${DateTime.now().millisecondsSinceEpoch}';
    final emp = EmployeeModel(
      id: newId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      country: country,
      targetCurrency: targetCurrency,
      status: 'INVITED',
    );
    _employees.add(emp);
    return 'https://bmoni.com/invite/flowpay_$newId';
  }
}

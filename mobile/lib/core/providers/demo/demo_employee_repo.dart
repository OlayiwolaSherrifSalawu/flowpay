import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/employee_repository.dart';
import 'demo_data.dart';

class DemoEmployeeRepository implements EmployeeRepository {
  final List<EmployeeModel> _employees = List.from(DemoData.employees);

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_employees);
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
    String? countryName,
    required Currency targetCurrency,
    Money? payrollAmount,
    Money? usdPayrollAmount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newId = 'emp_demo_${DateTime.now().millisecondsSinceEpoch}';
    final randomHex = (1000 + _employees.length).toString();
    final emp = EmployeeModel(
      id: newId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      country: country,
      countryName: countryName ?? (country == 'NG' ? 'Nigeria' : country == 'MX' ? 'Mexico' : 'Canada'),
      targetCurrency: targetCurrency,
      status: 'ACTIVE',
      onboardingStatus: 'ONBOARDED',
      walletStatus: 'PROVISIONED',
      cardStatus: 'ACTIVE',
      payrollAmount: payrollAmount ?? Money.fromMajorString('2000.00', targetCurrency),
      usdPayrollAmount: usdPayrollAmount ?? Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: '0x$randomHex...${DateTime.now().millisecond}A',
      cardId: 'card_demo_${newId.substring(0, 8)}',
      cardLast4: (4000 + _employees.length * 111).toString(),
    );
    _employees.add(emp);
    return 'https://bmoni.com/invite/flowpay_$newId';
  }
}


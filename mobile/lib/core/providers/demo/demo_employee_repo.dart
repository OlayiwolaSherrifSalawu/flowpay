import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/employee_repository.dart';
import 'demo_data.dart';

class DemoEmployeeRepository implements EmployeeRepository {
  final List<EmployeeModel> _employees = List.from(DemoData.employees);
  final Map<String, Map<String, dynamic>> _demoInvites = {};

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
    await Future.delayed(const Duration(milliseconds: 300));
    final newId = 'emp_demo_${DateTime.now().millisecondsSinceEpoch}';
    final demoUserId = 'usr_demo_${newId.substring(4)}';

    final emp = EmployeeModel(
      id: newId,
      flowpayUserId: demoUserId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      country: country,
      countryName: countryName ?? '',
      targetCurrency: targetCurrency,
      status: EmployeeLifecycleStages.invited,
      onboardingStatus: EmployeeLifecycleStages.invited,
      walletStatus: 'NONE',
      cardStatus: 'NONE',
      payrollAmount: payrollAmount,
      usdPayrollAmount:
          usdPayrollAmount ?? Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: null,
      inviteUrl: 'https://app.flowpay.finance/invite/token_demo_${newId.substring(4)}',
    );
    _employees.add(emp);
    final inviteToken = 'token_demo_${newId.substring(4)}';
    _demoInvites[inviteToken] = {
      'inviteToken': inviteToken,
      'employeeId': newId,
      'userId': demoUserId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'country': country,
      'targetCurrency': targetCurrency.code,
      'payrollAmountMinor': payrollAmount.minorUnits,
      'expiresAt':
          DateTime.now().add(const Duration(hours: 72)).toIso8601String(),
    };
    return 'https://app.flowpay.finance/invite/$inviteToken';
  }

  EmployeeModel _copy(EmployeeModel old, {String? status, String? walletAddress, String? inviteUrl}) => EmployeeModel(
        id: old.id,
        firstName: old.firstName,
        lastName: old.lastName,
        email: old.email,
        phoneNumber: old.phoneNumber,
        country: old.country,
        countryName: old.countryName,
        targetCurrency: old.targetCurrency,
        status: status ?? old.status,
        onboardingStatus: status ?? old.onboardingStatus,
        walletStatus: (walletAddress ?? old.walletAddress) != null ? 'ACTIVE' : 'NONE',
        cardStatus: old.cardStatus,
        payrollAmount: old.payrollAmount,
        usdPayrollAmount: old.usdPayrollAmount,
        walletAddress: walletAddress ?? old.walletAddress,
        inviteUrl: inviteUrl ?? old.inviteUrl,
      );

  @override
  Future<String> resendInvite(String employeeId) async {
    final idx = _employees.indexWhere((e) => e.id == employeeId);
    if (idx == -1) throw StateError('Employee not found');
    final token = 'token_demo_${DateTime.now().millisecondsSinceEpoch}';
    final url = 'https://app.flowpay.finance/invite/$token';
    _demoInvites[token] = {..._demoInvites.values.firstWhere((i) => i['employeeId'] == employeeId, orElse: () => {'employeeId': employeeId})};
    _employees[idx] = _copy(_employees[idx], inviteUrl: url);
    return url;
  }

  @override
  Future<Map<String, dynamic>> getInviteDetails(String token) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final invite = _demoInvites[token.trim()];
    if (invite == null) throw StateError('This invitation link is not valid.');
    return Map<String, dynamic>.from(invite);
  }

  @override
  Future<EmployeeModel> acceptInvite(String token) async {
    final invite = _demoInvites.remove(token.trim());
    if (invite == null) throw StateError('This invitation link is not valid.');
    final idx = _employees.indexWhere((e) => e.id == invite['employeeId']);
    if (idx == -1) throw StateError('Employee not found');
    _employees[idx] = _copy(_employees[idx], status: EmployeeLifecycleStages.ready, walletAddress: 'GDEMO${idx.toString().padLeft(51, 'X')}');
    return _employees[idx];
  }

  @override
  Future<EmployeeModel> setEmployeeStatus(String employeeId, String status) async {
    final idx = _employees.indexWhere((e) => e.id == employeeId);
    if (idx == -1) throw StateError('Employee not found');
    _employees[idx] = _copy(_employees[idx], status: status.toUpperCase());
    return _employees[idx];
  }
}

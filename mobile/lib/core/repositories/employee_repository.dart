import '../money/currency.dart';

class EmployeeModel {
  final String id;
  final String? bmoniUserId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String country;
  final Currency targetCurrency;
  final String status; // INVITED, LINKED, ACTIVE
  final String? walletAddress;
  final String? cardId;

  const EmployeeModel({
    required this.id,
    this.bmoniUserId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.country,
    required this.targetCurrency,
    required this.status,
    this.walletAddress,
    this.cardId,
  });

  String get fullName => '$firstName $lastName';
}

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees();
  Future<EmployeeModel> getEmployeeById(String id);
  Future<String> inviteEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String country,
    required Currency targetCurrency,
  });
}

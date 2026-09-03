import '../money/currency.dart';
import '../money/money.dart';

class EmployeeModel {
  final String id;
  final String? bmoniUserId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String country; // "NG", "MX", "CA"
  final String countryName; // "Nigeria", "Mexico", "Canada"
  final Currency targetCurrency;
  final String status; // INVITED, LINKED, ACTIVE
  final String onboardingStatus; // ONBOARDED, ACTIVE, INVITED, PENDING
  final String walletStatus; // PROVISIONED, ACTIVE, PENDING
  final String cardStatus; // ACTIVE, ISSUED, FROZEN, PENDING
  final Money? payrollAmount;
  final Money? usdPayrollAmount;
  final String? walletAddress;
  final String? cardId;
  final String? cardLast4;

  const EmployeeModel({
    required this.id,
    this.bmoniUserId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.country,
    this.countryName = '',
    required this.targetCurrency,
    required this.status,
    this.onboardingStatus = 'ACTIVE',
    this.walletStatus = 'ACTIVE',
    this.cardStatus = 'ACTIVE',
    this.payrollAmount,
    this.usdPayrollAmount,
    this.walletAddress,
    this.cardId,
    this.cardLast4,
  });

  String get fullName => '$firstName $lastName';

  String get resolvedCountryName {
    if (countryName.isNotEmpty) return countryName;
    switch (country.toUpperCase()) {
      case 'NG':
        return 'Nigeria';
      case 'MX':
        return 'Mexico';
      case 'CA':
        return 'Canada';
      default:
        return country;
    }
  }

  String get flagEmoji {
    switch (country.toUpperCase()) {
      case 'NG':
        return '🇳🇬';
      case 'MX':
        return '🇲🇽';
      case 'CA':
        return '🇨🇦';
      default:
        return '🌐';
    }
  }
}

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees();
  Future<EmployeeModel> getEmployeeById(String id);
  Future<String> inviteEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    Money? payrollAmount,
    Money? usdPayrollAmount,
  });
}


import '../money/currency.dart';
import '../money/money.dart';

/// The 6 lifecycle stages of an employee on FlowPay & BMONI rails:
/// 1. CREATED - User registered on BMONI rails (POST /v1/users), has bmoniUserId
/// 2. WALLET_PENDING - Awaiting on-device smart wallet provisioning & owner challenge
/// 3. KYC_PENDING - Awaiting KYC documents submission (or kyc.action_required)
/// 4. ONBOARDING - KYC under verification by provider
/// 5. READY - KYC verified, VBA provisioned, smart wallet active, ready for payroll
/// 6. FAILED - Onboarding or KYC failed; see failedStage
class EmployeeLifecycleStages {
  static const String created = 'CREATED';
  static const String walletPending = 'WALLET_PENDING';
  static const String kycPending = 'KYC_PENDING';
  static const String onboarding = 'ONBOARDING';
  static const String ready = 'READY';
  static const String failed = 'FAILED';
}

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
  final String
      status; // CREATED, WALLET_PENDING, KYC_PENDING, ONBOARDING, READY, FAILED
  final String? failedStage;
  final String
      onboardingStatus; // CREATED, WALLET_PENDING, KYC_PENDING, ONBOARDING, READY, FAILED
  final String walletStatus; // ACTIVE, PROVISIONED, PENDING, NONE
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
    this.failedStage,
    this.onboardingStatus = 'READY',
    this.walletStatus = 'ACTIVE',
    this.cardStatus = 'ACTIVE',
    this.payrollAmount,
    this.usdPayrollAmount,
    this.walletAddress,
    this.cardId,
    this.cardLast4,
  });

  String get fullName => '$firstName $lastName';

  bool get isReady => status.toUpperCase() == EmployeeLifecycleStages.ready;
  bool get isFailed => status.toUpperCase() == EmployeeLifecycleStages.failed;

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

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final countryCode = (json['country'] ?? 'NG').toString().toUpperCase();
    final targetCurr = Currency.fromCode(
        json['target_currency'] ?? json['targetCurrency'] ?? 'USD');

    // Parse payroll amount
    Money? payroll;
    if (json['payroll_amount_minor'] != null) {
      payroll =
          Money.fromMinor(json['payroll_amount_minor'] as int, targetCurr);
    } else if (json['payroll_amount'] != null) {
      payroll = Money.fromMinor(json['payroll_amount'] as int, targetCurr);
    } else if (json['payrollAmount'] != null) {
      payroll = Money.fromMinor(json['payrollAmount'] as int, targetCurr);
    }

    Money? usdPayroll;
    if (json['usd_payroll_amount'] != null) {
      usdPayroll =
          Money.fromMinor(json['usd_payroll_amount'] as int, Currency.usd);
    } else if (json['usdPayrollAmount'] != null) {
      usdPayroll =
          Money.fromMinor(json['usdPayrollAmount'] as int, Currency.usd);
    }

    final rawStatus = (json['status'] ?? 'CREATED').toString().toUpperCase();

    return EmployeeModel(
      id: json['id'] ?? '',
      bmoniUserId: json['bmoni_user_id'] ?? json['bmoniUserId'],
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      country: countryCode,
      countryName: json['country_name'] ?? json['countryName'] ?? '',
      targetCurrency: targetCurr,
      status: rawStatus,
      failedStage: json['failed_stage'] ?? json['failedStage'],
      onboardingStatus:
          json['onboarding_status'] ?? json['onboardingStatus'] ?? rawStatus,
      walletStatus: json['wallet_status'] ?? json['walletStatus'] ?? 'ACTIVE',
      cardStatus: json['card_status'] ?? json['cardStatus'] ?? 'ACTIVE',
      payrollAmount: payroll,
      usdPayrollAmount: usdPayroll,
      walletAddress: json['wallet_address'] ?? json['walletAddress'],
      cardId: json['card_id'] ?? json['cardId'],
      cardLast4: json['card_last4'] ?? json['cardLast4'] ?? '4289',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bmoniUserId': bmoniUserId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'country': country,
      'countryName': countryName,
      'targetCurrency': targetCurrency.code,
      'status': status,
      'failedStage': failedStage,
      'onboardingStatus': onboardingStatus,
      'walletStatus': walletStatus,
      'cardStatus': cardStatus,
      'payrollAmountMinor': payrollAmount?.minorUnits,
      'usdPayrollAmountMinor': usdPayrollAmount?.minorUnits,
      'walletAddress': walletAddress,
      'cardId': cardId,
      'cardLast4': cardLast4,
    };
  }
}

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees();
  Future<EmployeeModel> getEmployeeById(String id);

  /// Primary employee creation method calling POST /api/employees
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
  });

  /// Backward compatible legacy wrapper
  @Deprecated('Use createEmployee instead.')
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

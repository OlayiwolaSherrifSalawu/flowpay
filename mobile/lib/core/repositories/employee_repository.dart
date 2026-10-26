import '../money/currency.dart';
import '../money/money.dart';

/// Employee lifecycle on Stellar:
/// INVITED   — added by the employer; invite link sent, no wallet yet
/// READY     — accepted with their own proven Stellar wallet; payable
/// SUSPENDED — excluded from payroll by the employer
/// (CREATED/WALLET_PENDING/KYC_PENDING/ONBOARDING/FAILED are legacy BMONI stages.)
class EmployeeLifecycleStages {
  static const String invited = 'INVITED';
  static const String suspended = 'SUSPENDED';
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
  final String? failureReason;

  /// Current shareable invite link (INVITED employees only).
  final String? inviteUrl;

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
    this.failureReason,
    this.inviteUrl,
  });

  String get fullName => '$firstName $lastName';
  double get salaryAmount => payrollAmount?.majorUnits ?? 0;

  bool get isReady => status.toUpperCase() == EmployeeLifecycleStages.ready;
  bool get isFailed => status.toUpperCase() == EmployeeLifecycleStages.failed;

  /// Collapses the detailed lifecycle stage into the simple 3-state label
  /// product/design actually wants surfaced in list rows: Pending, Onboarded,
  /// or Failed. Use `status`/`onboardingStatus` directly when you need the
  /// full-fidelity stage (e.g. for the multi-stage onboarding screen).
  String get simpleStatusLabel {
    final s = status.toUpperCase();
    if (s == EmployeeLifecycleStages.ready ||
        s == 'ACTIVE' ||
        s == 'LINKED') {
      return 'Onboarded';
    }
    if (s == EmployeeLifecycleStages.failed) {
      return 'Failed';
    }
    if (s == EmployeeLifecycleStages.suspended) {
      return 'Suspended';
    }
    // INVITED, CREATED, WALLET_PENDING, KYC_PENDING, ONBOARDING all read as
    // "Pending" to a business owner glancing at the team list.
    return 'Pending';
  }

  /// Short, human-friendly wallet identifier for list/detail display.
  /// Falls back to the wallet id if the on-chain address isn't set yet.
  String? get displayWalletId {
    final addr = walletAddress;
    if (addr != null && addr.isNotEmpty) {
      if (addr.length > 12) {
        return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
      }
      return addr;
    }
    return null;
  }

  String get resolvedCountryName {
    if (countryName.isNotEmpty) return countryName;
    switch (country.toUpperCase()) {
      case 'NG':
        return 'Nigeria';
      case 'MX':
        return 'Mexico';
      case 'CA':
        return 'Canada';
      case 'US':
        return 'United States';
      case 'GB':
        return 'United Kingdom';
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
      case 'US':
        return '🇺🇸';
      case 'GB':
        return '🇬🇧';
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
    final rawPayroll = json['payroll_amount_minor'] ??
        json['payrollAmountMinor'] ??
        json['payroll_amount'] ??
        json['payrollAmount'];
    if (rawPayroll != null && rawPayroll is num) {
      payroll = Money.fromMinor(rawPayroll.toInt(), targetCurr);
    } else if (rawPayroll != null) {
      final parsed = int.tryParse(rawPayroll.toString());
      if (parsed != null) {
        payroll = Money.fromMinor(parsed, targetCurr);
      }
    }

    Money? usdPayroll;
    final rawUsdPayroll = json['usd_payroll_amount_minor'] ??
        json['usdPayrollAmountMinor'] ??
        json['usd_payroll_amount'] ??
        json['usdPayrollAmount'];
    if (rawUsdPayroll != null && rawUsdPayroll is num) {
      usdPayroll = Money.fromMinor(rawUsdPayroll.toInt(), Currency.usd);
    } else if (rawUsdPayroll != null) {
      final parsed = int.tryParse(rawUsdPayroll.toString());
      if (parsed != null) {
        usdPayroll = Money.fromMinor(parsed, Currency.usd);
      }
    }

    final rawStatus = (json['status'] ?? 'CREATED').toString().toUpperCase();

    final walletAddr = json['wallet_address'] ?? json['walletAddress'];
    final cardIdVal = json['card_id'] ?? json['cardId'];

    // Derive wallet/card status TRUTHFULLY. The backend does not send
    // wallet_status/card_status columns, so we must infer them from real data
    // instead of fabricating 'ACTIVE'. Showing a fake ACTIVE wallet/card on a
    // FAILED or not-yet-onboarded employee hides real state in a fintech app.
    final explicitWalletStatus = json['wallet_status'] ?? json['walletStatus'];
    final derivedWalletStatus = explicitWalletStatus ??
        ((walletAddr != null && walletAddr.toString().isNotEmpty)
            ? 'ACTIVE'
            : 'NONE');

    final explicitCardStatus = json['card_status'] ?? json['cardStatus'];
    final derivedCardStatus = explicitCardStatus ??
        ((cardIdVal != null && cardIdVal.toString().isNotEmpty)
            ? 'ACTIVE'
            : 'NONE');

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
      walletStatus: derivedWalletStatus,
      cardStatus: derivedCardStatus,
      payrollAmount: payroll,
      usdPayrollAmount: usdPayroll,
      walletAddress: walletAddr,
      cardId: cardIdVal,
      // Only surface a real last-4; never invent one.
      cardLast4: json['card_last4'] ?? json['cardLast4'],
      failureReason: json['failure_reason'] ?? json['failureReason'],
      inviteUrl: json['inviteUrl']?.toString(),
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
      'failureReason': failureReason,
    };
  }
}

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees();
  Future<EmployeeModel> getEmployeeById(String id);

  /// Adds an employee and returns their single-use invite link.
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

  /// Issues a new invite link (the previous one stops working).
  Future<String> resendInvite(String employeeId);

  /// Public invite details for the person opening an invite link.
  Future<Map<String, dynamic>> getInviteDetails(String token);

  /// The signed-in user accepts an invite with their proven Stellar wallet.
  Future<EmployeeModel> acceptInvite(String token);

  /// SUSPENDED / READY / INVITED (constrained by the server).
  Future<EmployeeModel> setEmployeeStatus(String employeeId, String status);
}

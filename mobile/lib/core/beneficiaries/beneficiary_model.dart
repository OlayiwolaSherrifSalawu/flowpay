import '../money/currency.dart';

/// FlowPay Beneficiary Domain Model
/// Represents a trusted counterparty with legal identity and nickname / relationship alias.
class Beneficiary {
  final String id;
  final String nickname; // e.g. "Mom", "Designer", "Contractor MX"
  final String legalName; // e.g. "Mary Fashola", "Bunch Dillon", "Samson Jabo"
  final String relationship; // e.g. "Mother", "Contractor", "Family", "Employee"
  final String destinationCountry; // e.g. "Nigeria", "Mexico", "United States", "Canada"
  final String countryFlag; // e.g. "🇳🇬", "🇲🇽", "🇺🇸", "🇨🇦"
  final Currency currency;
  final String accountOrAddress; // e.g. "0x3A9a...F242" or "0123456789 (Access Bank)"
  final bool isVerified;
  final int paymentCount;
  final DateTime? lastPaymentDate;

  const Beneficiary({
    required this.id,
    required this.nickname,
    required this.legalName,
    required this.relationship,
    required this.destinationCountry,
    required this.countryFlag,
    required this.currency,
    required this.accountOrAddress,
    this.isVerified = true,
    this.paymentCount = 0,
    this.lastPaymentDate,
  });

  Beneficiary copyWith({
    String? id,
    String? nickname,
    String? legalName,
    String? relationship,
    String? destinationCountry,
    String? countryFlag,
    Currency? currency,
    String? accountOrAddress,
    bool? isVerified,
    int? paymentCount,
    DateTime? lastPaymentDate,
  }) {
    return Beneficiary(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      legalName: legalName ?? this.legalName,
      relationship: relationship ?? this.relationship,
      destinationCountry: destinationCountry ?? this.destinationCountry,
      countryFlag: countryFlag ?? this.countryFlag,
      currency: currency ?? this.currency,
      accountOrAddress: accountOrAddress ?? this.accountOrAddress,
      isVerified: isVerified ?? this.isVerified,
      paymentCount: paymentCount ?? this.paymentCount,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'legalName': legalName,
        'relationship': relationship,
        'destinationCountry': destinationCountry,
        'countryFlag': countryFlag,
        'currencyCode': currency.code,
        'accountOrAddress': accountOrAddress,
        'isVerified': isVerified,
        'paymentCount': paymentCount,
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      };

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        legalName: json['legalName'] as String,
        relationship: json['relationship'] as String? ?? 'Contact',
        destinationCountry: json['destinationCountry'] as String,
        countryFlag: json['countryFlag'] as String? ?? '🌐',
        currency: Currency.fromCode(json['currencyCode'] as String? ?? 'USD'),
        accountOrAddress: json['accountOrAddress'] as String,
        isVerified: json['isVerified'] as bool? ?? true,
        paymentCount: json['paymentCount'] as int? ?? 0,
        lastPaymentDate: json['lastPaymentDate'] != null
            ? DateTime.tryParse(json['lastPaymentDate'] as String)
            : null,
      );
}

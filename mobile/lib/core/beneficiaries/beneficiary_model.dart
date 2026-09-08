import '../money/currency.dart';

/// FlowPay Beneficiary Domain Model
/// Represents a trusted counterparty with legal identity and nickname / relationship alias.
class Beneficiary {
  final String id;
  final String nickname; // e.g. "Mom", "Designer", "Contractor MX"
  final String legalName; // e.g. "Mary Fashola", "Bunch Dillon", "Samson Jabo"
  final List<String> aliases; // e.g. ["Mom", "Mother", "Mum"]
  final String relationship; // e.g. "Mother", "Contractor", "Family", "Employee"
  final String destinationCountry; // e.g. "Nigeria", "Mexico", "Ghana", "Canada"
  final String countryFlag; // e.g. "🇳🇬", "🇲🇽", "🇬🇭", "🇺🇸", "🇨🇦"
  final String destinationType; // e.g. "bank_account", "mobile_money", "evm_wallet"
  final Currency currency; // Destination currency the recipient ultimately receives
  final Currency? preferredFundingCurrency; // e.g. USD
  final String accountOrAddress; // e.g. "0x3A9a...F242" or "0123456789 (Access Bank)"
  final bool isVerified;
  final int paymentCount;
  final DateTime? lastPaymentDate;

  const Beneficiary({
    required this.id,
    required this.nickname,
    required this.legalName,
    this.aliases = const [],
    required this.relationship,
    required this.destinationCountry,
    required this.countryFlag,
    this.destinationType = 'bank_account',
    required this.currency,
    this.preferredFundingCurrency,
    required this.accountOrAddress,
    this.isVerified = true,
    this.paymentCount = 0,
    this.lastPaymentDate,
  });

  /// Recipient destination currency alias
  Currency get destinationCurrency => currency;

  /// User-friendly display name
  String get displayName {
    if (nickname.isNotEmpty &&
        nickname.toLowerCase() != legalName.toLowerCase()) {
      return '$legalName ($nickname)';
    }
    return legalName.isNotEmpty ? legalName : nickname;
  }

  /// All searchable aliases including nickname, legal name, and aliases array
  List<String> get allAliases {
    final list = <String>[];
    if (nickname.isNotEmpty) list.add(nickname);
    if (legalName.isNotEmpty) list.add(legalName);
    list.addAll(aliases);
    return list;
  }

  Beneficiary copyWith({
    String? id,
    String? nickname,
    String? legalName,
    List<String>? aliases,
    String? relationship,
    String? destinationCountry,
    String? countryFlag,
    String? destinationType,
    Currency? currency,
    Currency? preferredFundingCurrency,
    String? accountOrAddress,
    bool? isVerified,
    int? paymentCount,
    DateTime? lastPaymentDate,
  }) {
    return Beneficiary(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      legalName: legalName ?? this.legalName,
      aliases: aliases ?? this.aliases,
      relationship: relationship ?? this.relationship,
      destinationCountry: destinationCountry ?? this.destinationCountry,
      countryFlag: countryFlag ?? this.countryFlag,
      destinationType: destinationType ?? this.destinationType,
      currency: currency ?? this.currency,
      preferredFundingCurrency:
          preferredFundingCurrency ?? this.preferredFundingCurrency,
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
        'aliases': aliases,
        'relationship': relationship,
        'destinationCountry': destinationCountry,
        'countryFlag': countryFlag,
        'destinationType': destinationType,
        'currencyCode': currency.code,
        'preferredFundingCurrency': preferredFundingCurrency?.code,
        'accountOrAddress': accountOrAddress,
        'isVerified': isVerified,
        'paymentCount': paymentCount,
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      };

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        legalName: json['legalName'] as String,
        aliases: (json['aliases'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        relationship: json['relationship'] as String? ?? 'Contact',
        destinationCountry: json['destinationCountry'] as String,
        countryFlag: json['countryFlag'] as String? ?? '🌐',
        destinationType: json['destinationType'] as String? ?? 'bank_account',
        currency: Currency.fromCode(json['currencyCode'] as String? ?? 'USD'),
        preferredFundingCurrency: json['preferredFundingCurrency'] != null
            ? Currency.fromCode(json['preferredFundingCurrency'] as String)
            : null,
        accountOrAddress: json['accountOrAddress'] as String,
        isVerified: json['isVerified'] as bool? ?? true,
        paymentCount: json['paymentCount'] as int? ?? 0,
        lastPaymentDate: json['lastPaymentDate'] != null
            ? DateTime.tryParse(json['lastPaymentDate'] as String)
            : null,
      );
}

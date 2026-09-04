import '../money/currency.dart';

class TransferIntent {
  final String intentId;
  final String originalPrompt;
  final String recipient;
  final String amount; // e.g. "500.00"
  final String amountMinor; // e.g. "50000"
  final Currency currency;
  final String? purpose;
  final double confidenceScore;
  final bool requiresExplicitApproval; // Invariant: Always true
  final String? provider;

  const TransferIntent({
    required this.intentId,
    required this.originalPrompt,
    required this.recipient,
    required this.amount,
    required this.amountMinor,
    required this.currency,
    this.purpose,
    this.confidenceScore = 0.95,
    this.requiresExplicitApproval = true,
    this.provider,
  });

  factory TransferIntent.fromJson(Map<String, dynamic> json) {
    final curStr = json['currency']?.toString() ?? 'USD';
    return TransferIntent(
      intentId: json['intentId']?.toString() ?? 'tx_intent_${DateTime.now().millisecondsSinceEpoch}',
      originalPrompt: json['originalPrompt']?.toString() ?? '',
      recipient: json['recipient']?.toString() ?? 'Beneficiary',
      amount: json['amount']?.toString() ?? '0.00',
      amountMinor: json['amountMinor']?.toString() ?? '0',
      currency: Currency.fromCode(curStr),
      purpose: json['purpose']?.toString(),
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.95,
      requiresExplicitApproval: true,
      provider: json['provider']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'intentId': intentId,
        'originalPrompt': originalPrompt,
        'recipient': recipient,
        'amount': amount,
        'amountMinor': amountMinor,
        'currency': currency.code,
        if (purpose != null) 'purpose': purpose,
        'confidenceScore': confidenceScore,
        'requiresExplicitApproval': requiresExplicitApproval,
        if (provider != null) 'provider': provider,
      };

  TransferIntent copyWith({
    String? intentId,
    String? originalPrompt,
    String? recipient,
    String? amount,
    String? amountMinor,
    Currency? currency,
    String? purpose,
    double? confidenceScore,
    String? provider,
  }) {
    return TransferIntent(
      intentId: intentId ?? this.intentId,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      recipient: recipient ?? this.recipient,
      amount: amount ?? this.amount,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      purpose: purpose ?? this.purpose,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      requiresExplicitApproval: true,
      provider: provider ?? this.provider,
    );
  }
}

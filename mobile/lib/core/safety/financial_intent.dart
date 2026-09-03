import '../money/currency.dart';

enum FinancialOperationType {
  transfer,
  payrollRun,
  cardIssue,
  cardStatusToggle,
  missionCreate,
}

class FinancialIntent {
  final String intentId;
  final String rawPrompt;
  final FinancialOperationType operationType;
  final String? recipientIdentifier;
  final Currency sourceCurrency;
  final Currency? targetCurrency;
  final String amountMinor;
  final String amountFormatted;
  final String description;
  final double confidenceScore;
  final bool requiresExplicitApproval;

  const FinancialIntent({
    required this.intentId,
    required this.rawPrompt,
    required this.operationType,
    this.recipientIdentifier,
    required this.sourceCurrency,
    this.targetCurrency,
    required this.amountMinor,
    required this.amountFormatted,
    required this.description,
    this.confidenceScore = 1.0,
    this.requiresExplicitApproval = true,
  });

  factory FinancialIntent.fromJson(Map<String, dynamic> json) {
    final params = (json['parameters'] as Map<String, dynamic>?) ?? {};
    final opStr = json['operationType'] as String? ?? 'TRANSFER';

    FinancialOperationType op;
    switch (opStr) {
      case 'PAYROLL_RUN':
        op = FinancialOperationType.payrollRun;
        break;
      case 'CARD_ISSUE':
        op = FinancialOperationType.cardIssue;
        break;
      case 'MISSION_CREATE':
        op = FinancialOperationType.missionCreate;
        break;
      default:
        op = FinancialOperationType.transfer;
    }

    return FinancialIntent(
      intentId: json['intentId'] ?? '',
      rawPrompt: json['originalPrompt'] ?? '',
      operationType: op,
      recipientIdentifier: params['recipientIdentifier'],
      sourceCurrency: Currency.fromCode(params['sourceCurrency'] ?? 'USD'),
      targetCurrency: params['targetCurrency'] != null
          ? Currency.fromCode(params['targetCurrency'])
          : null,
      amountMinor: params['amountMinor']?.toString() ?? '0',
      amountFormatted: params['amountFormatted']?.toString() ?? '0.00',
      description: params['description'] ?? json['explanation'] ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 1.0,
      requiresExplicitApproval: true,
    );
  }
}

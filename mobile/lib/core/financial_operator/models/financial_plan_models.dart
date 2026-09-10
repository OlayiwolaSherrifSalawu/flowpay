import '../../money/currency.dart';
import '../../money/money.dart';
import '../../transfers/transfer_models.dart';

enum PlannedActionType {
  send,
  reserve,
  allocate,
  convert,
  createMission,
  billPay;

  String get displayName {
    switch (this) {
      case PlannedActionType.send:
        return 'Send';
      case PlannedActionType.reserve:
        return 'Reserve';
      case PlannedActionType.allocate:
        return 'Allocate';
      case PlannedActionType.convert:
        return 'Convert';
      case PlannedActionType.createMission:
        return 'Set Rule';
      case PlannedActionType.billPay:
        return 'Pay Bill';
    }
  }
}

/// Balance Impact line item showing before/after projections per wallet
class BalanceImpact {
  final String walletId;
  final String walletName;
  final Currency currency;
  final Money currentBalance;
  final Money projectedBalance;
  final Money delta; // Negative for debit, positive for credit

  const BalanceImpact({
    required this.walletId,
    required this.walletName,
    required this.currency,
    required this.currentBalance,
    required this.projectedBalance,
    required this.delta,
  });

  bool get isDebit => delta.minorUnits < 0;
  bool get isCredit => delta.minorUnits > 0;
}

/// Deterministic validation output
class PlanValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const PlanValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory PlanValidationResult.valid({List<String> warnings = const []}) {
    return PlanValidationResult(isValid: true, warnings: warnings);
  }

  factory PlanValidationResult.invalid(List<String> errors,
      {List<String> warnings = const []}) {
    return PlanValidationResult(
        isValid: false, errors: errors, warnings: warnings);
  }
}

/// A line item in the financial plan
class PlannedFinancialAction {
  final String id;
  final PlannedActionType type;
  final Money amount;
  final String? percentageLabel;
  final String sourceWalletId;
  final String sourceWalletName;
  final String destinationId;
  final String destinationName;
  final String? destinationAddress;
  final String destinationType; // 'beneficiary', 'reserve', 'wallet'
  final String description;
  final String? fxRate;
  final Money fee;
  final Money? destinationAmount; // e.g. ₦775,000.00 NGN
  final Currency? destinationCurrency;
  final String? destinationRail;
  final Currency? fundingCurrency;
  final String status; // 'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'
  final String? txHash;
  final String? executionError;
  final List<String> dependsOn;
  final String? proposalId;

  const PlannedFinancialAction({
    required this.id,
    required this.type,
    required this.amount,
    this.percentageLabel,
    required this.sourceWalletId,
    required this.sourceWalletName,
    required this.destinationId,
    required this.destinationName,
    this.destinationAddress,
    required this.destinationType,
    required this.description,
    this.fxRate,
    required this.fee,
    this.destinationAmount,
    this.destinationCurrency,
    this.destinationRail,
    this.fundingCurrency,
    this.status = 'PENDING',
    this.txHash,
    this.executionError,
    this.dependsOn = const [],
    this.proposalId,
  });

  PlannedFinancialAction copyWith({
    String? id,
    PlannedActionType? type,
    Money? amount,
    String? percentageLabel,
    String? sourceWalletId,
    String? sourceWalletName,
    String? destinationId,
    String? destinationName,
    String? destinationAddress,
    String? destinationType,
    String? description,
    String? fxRate,
    Money? fee,
    Money? destinationAmount,
    Currency? destinationCurrency,
    String? destinationRail,
    Currency? fundingCurrency,
    String? status,
    String? txHash,
    String? executionError,
    List<String>? dependsOn,
    String? proposalId,
  }) {
    return PlannedFinancialAction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      percentageLabel: percentageLabel ?? this.percentageLabel,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      sourceWalletName: sourceWalletName ?? this.sourceWalletName,
      destinationId: destinationId ?? this.destinationId,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationType: destinationType ?? this.destinationType,
      description: description ?? this.description,
      fxRate: fxRate ?? this.fxRate,
      fee: fee ?? this.fee,
      destinationAmount: destinationAmount ?? this.destinationAmount,
      destinationCurrency: destinationCurrency ?? this.destinationCurrency,
      destinationRail: destinationRail ?? this.destinationRail,
      fundingCurrency: fundingCurrency ?? this.fundingCurrency,
      status: status ?? this.status,
      txHash: txHash ?? this.txHash,
      executionError: executionError ?? this.executionError,
      dependsOn: dependsOn ?? this.dependsOn,
      proposalId: proposalId ?? this.proposalId,
    );
  }
}

/// Structured Financial Plan
/// Immutable specification generated by the Financial Planner and passed to the
/// Policy Validator and User Review before execution authorization.
class FinancialPlan {
  final String planId;
  final String title;
  final String summary;
  final List<PlannedFinancialAction> actions;
  final Money totalDebit;
  final Money totalFee;
  final List<BalanceImpact> expectedBalanceChanges;
  final PlanValidationResult validation;
  final bool isApproved;
  final DateTime createdAt;
  final String executionState; // DRAFT, READY_FOR_REVIEW, APPROVED, EXECUTING, COMPLETED, FAILED
  final String? txHash;
  final String? routeExplanation; // e.g. "Why did you use my EUR?"
  final List<String> availableRouteOverrides;
  final Currency? selectedFundingCurrency;
  final DateTime? quoteExpiresAt;
  final Money? shortfall;
  final String? proposalId;
  final String? hashToSign;
  final TransferProposal? transferProposal;
  final List<TransferProposal> transferProposals;

  const FinancialPlan({
    required this.planId,
    required this.title,
    required this.summary,
    required this.actions,
    required this.totalDebit,
    required this.totalFee,
    required this.expectedBalanceChanges,
    required this.validation,
    this.isApproved = false,
    required this.createdAt,
    this.executionState = 'READY_FOR_REVIEW',
    this.txHash,
    this.routeExplanation,
    this.availableRouteOverrides = const [],
    this.selectedFundingCurrency,
    this.quoteExpiresAt,
    this.shortfall,
    this.proposalId,
    this.hashToSign,
    this.transferProposal,
    this.transferProposals = const [],
  });

  bool get isQuoteExpired =>
      quoteExpiresAt != null && DateTime.now().isAfter(quoteExpiresAt!);

  Money get totalRequested {
    if (actions.isEmpty) return totalDebit;
    return actions.fold(
      Money.zero(actions.first.amount.currency),
      (sum, act) => sum.add(act.amount),
    );
  }

  FinancialPlan copyWith({
    String? planId,
    String? title,
    String? summary,
    List<PlannedFinancialAction>? actions,
    Money? totalDebit,
    Money? totalFee,
    List<BalanceImpact>? expectedBalanceChanges,
    PlanValidationResult? validation,
    bool? isApproved,
    DateTime? createdAt,
    String? executionState,
    String? txHash,
    String? routeExplanation,
    List<String>? availableRouteOverrides,
    Currency? selectedFundingCurrency,
    DateTime? quoteExpiresAt,
    Money? shortfall,
    String? proposalId,
    String? hashToSign,
    TransferProposal? transferProposal,
    List<TransferProposal>? transferProposals,
  }) {
    return FinancialPlan(
      planId: planId ?? this.planId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      actions: actions ?? this.actions,
      totalDebit: totalDebit ?? this.totalDebit,
      totalFee: totalFee ?? this.totalFee,
      expectedBalanceChanges:
          expectedBalanceChanges ?? this.expectedBalanceChanges,
      validation: validation ?? this.validation,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      executionState: executionState ?? this.executionState,
      txHash: txHash ?? this.txHash,
      routeExplanation: routeExplanation ?? this.routeExplanation,
      availableRouteOverrides:
          availableRouteOverrides ?? this.availableRouteOverrides,
      selectedFundingCurrency:
          selectedFundingCurrency ?? this.selectedFundingCurrency,
      quoteExpiresAt: quoteExpiresAt ?? this.quoteExpiresAt,
      shortfall: shortfall ?? this.shortfall,
      proposalId: proposalId ?? this.proposalId,
      hashToSign: hashToSign ?? this.hashToSign,
      transferProposal: transferProposal ?? this.transferProposal,
      transferProposals: transferProposals ?? this.transferProposals,
    );
  }
}

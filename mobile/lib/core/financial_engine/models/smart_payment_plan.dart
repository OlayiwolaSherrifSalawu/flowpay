import '../../beneficiaries/beneficiary_model.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../financial_operator/models/financial_plan_models.dart';
import 'payment_execution_state.dart';
import 'quote_model.dart';

/// Single source funding allocation contributing to a payment or batch
class FundingAllocation {
  final String walletId;
  final String walletName;
  final Currency currency;
  final Money allocatedAmount; // Amount taken from this wallet in its native currency
  final bool requiresConversion;
  final Money convertedOutputAmount; // Amount produced in payment currency
  final PaymentQuote? quote;
  final Money fee;
  final String explanation;

  const FundingAllocation({
    required this.walletId,
    required this.walletName,
    required this.currency,
    required this.allocatedAmount,
    this.requiresConversion = false,
    required this.convertedOutputAmount,
    this.quote,
    required this.fee,
    required this.explanation,
  });
}

/// A single payment item inside a multi-payment batch
class SmartPaymentItem {
  final String id;
  final Beneficiary recipient;
  final Money displayAmount; // User thought amount (e.g. $500.00 USD)
  final Money destinationAmount; // What recipient receives (e.g. ₦775,000.00 NGN)
  final Currency destinationCurrency;
  final String destinationType; // bank_account, mobile_money, evm_wallet
  final String destinationRail; // e.g. "Nigerian Bank Account", "Ghana Mobile Money"
  final PaymentQuote? quote;
  final Money fee;
  final String description;

  const SmartPaymentItem({
    required this.id,
    required this.recipient,
    required this.displayAmount,
    required this.destinationAmount,
    required this.destinationCurrency,
    required this.destinationType,
    required this.destinationRail,
    this.quote,
    required this.fee,
    required this.description,
  });
}

/// Smart Payment Batch Plan
/// Comprehensive financial blueprint for single or multi-recipient payments,
/// detailing shortfall funding, zero over-conversion, live quotes, and balance impacts.
class SmartPaymentBatchPlan {
  final String planId;
  final List<SmartPaymentItem> items;
  final Money totalRequested; // e.g. $2,500.00 USD
  final Money availableDirect; // e.g. $1,200.00 USD
  final Money shortfall; // e.g. $1,300.00 USD
  final List<FundingAllocation> fundingAllocations;
  final List<PaymentQuote> quotes;
  final List<BalanceImpact> expectedBalanceChanges;
  final String routeExplanation; // Data-driven reason for route selection ("Why EUR?")
  final List<String> availableRouteOverrides; // e.g. ["Use NGN instead"]
  final Currency selectedFundingCurrency; // e.g. EUR
  final DateTime quoteExpiresAt;
  final PlanValidationResult validation;
  final PaymentExecutionState executionState;
  final bool isApproved;
  final String? txHash;
  final DateTime createdAt;

  const SmartPaymentBatchPlan({
    required this.planId,
    required this.items,
    required this.totalRequested,
    required this.availableDirect,
    required this.shortfall,
    required this.fundingAllocations,
    required this.quotes,
    required this.expectedBalanceChanges,
    required this.routeExplanation,
    this.availableRouteOverrides = const [],
    this.selectedFundingCurrency = Currency.eur,
    required this.quoteExpiresAt,
    required this.validation,
    this.executionState = PaymentExecutionState.quoteReady,
    this.isApproved = false,
    this.txHash,
    required this.createdAt,
  });

  /// Check whether any quotes inside this plan have expired
  bool get isQuoteExpired =>
      DateTime.now().isAfter(quoteExpiresAt) ||
      quotes.any((q) => q.isExpired);

  /// Total provider & network fees across the plan
  Money get totalFee {
    int feeMinor = 0;
    for (final alloc in fundingAllocations) {
      feeMinor += alloc.fee.minorUnits;
    }
    for (final item in items) {
      feeMinor += item.fee.minorUnits;
    }
    return Money.fromMinor(feeMinor, totalRequested.currency);
  }

  /// Total display debit (requested + fees)
  Money get totalDebit => totalRequested.add(totalFee);

  SmartPaymentBatchPlan copyWith({
    String? planId,
    List<SmartPaymentItem>? items,
    Money? totalRequested,
    Money? availableDirect,
    Money? shortfall,
    List<FundingAllocation>? fundingAllocations,
    List<PaymentQuote>? quotes,
    List<BalanceImpact>? expectedBalanceChanges,
    String? routeExplanation,
    List<String>? availableRouteOverrides,
    Currency? selectedFundingCurrency,
    DateTime? quoteExpiresAt,
    PlanValidationResult? validation,
    PaymentExecutionState? executionState,
    bool? isApproved,
    String? txHash,
    DateTime? createdAt,
  }) {
    return SmartPaymentBatchPlan(
      planId: planId ?? this.planId,
      items: items ?? this.items,
      totalRequested: totalRequested ?? this.totalRequested,
      availableDirect: availableDirect ?? this.availableDirect,
      shortfall: shortfall ?? this.shortfall,
      fundingAllocations: fundingAllocations ?? this.fundingAllocations,
      quotes: quotes ?? this.quotes,
      expectedBalanceChanges:
          expectedBalanceChanges ?? this.expectedBalanceChanges,
      routeExplanation: routeExplanation ?? this.routeExplanation,
      availableRouteOverrides:
          availableRouteOverrides ?? this.availableRouteOverrides,
      selectedFundingCurrency:
          selectedFundingCurrency ?? this.selectedFundingCurrency,
      quoteExpiresAt: quoteExpiresAt ?? this.quoteExpiresAt,
      validation: validation ?? this.validation,
      executionState: executionState ?? this.executionState,
      isApproved: isApproved ?? this.isApproved,
      txHash: txHash ?? this.txHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

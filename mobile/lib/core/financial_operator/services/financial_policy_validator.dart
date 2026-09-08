import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/financial_plan_models.dart';
import 'financial_context_service.dart';

/// FlowPay Deterministic Financial Policy Validator
/// Enforces non-negotiable financial rules before any plan can be marked as
/// executable or presented for user approval. AI output is treated as untrusted input.
class FinancialPolicyValidator {
  static const Set<String> _allowedCurrencies = {
    'USD',
    'NGN',
    'MXN',
    'CAD',
    'EUR',
    'GBP',
    'GHS',
  };

  /// Validate a proposed FinancialPlan against real account state and safety policies
  static Future<PlanValidationResult> validate(
    FinancialPlan plan,
    FinancialContextService contextService,
  ) async {
    final errors = <String>[...plan.validation.errors];
    final warnings = <String>[...plan.validation.warnings];

    // 1. Actions non-empty check
    if (plan.actions.isEmpty) {
      errors.add('Plan contains zero actionable operations.');
      return PlanValidationResult.invalid(errors);
    }

    // 2. Quote expiration check
    if (plan.isQuoteExpired) {
      errors.add('Payment quote has expired. Please refresh to get current rates.');
    }

    // 3. Individual action checks
    for (final act in plan.actions) {
      // Amount must be strictly greater than zero
      if (act.amount.minorUnits <= 0) {
        errors.add(
            '${act.type.displayName} amount must be strictly greater than zero.');
      }

      // Currency must be supported
      if (!_allowedCurrencies.contains(act.amount.currency.code)) {
        errors.add(
            'Currency ${act.amount.currency.code} is not supported on FlowPay rails.');
      }

      // Recipient / Destination sanity
      if (act.type == PlannedActionType.send) {
        if (act.destinationId == 'unknown' ||
            act.destinationName.toLowerCase() == 'recipient' ||
            act.destinationName.isEmpty) {
          errors.add('Cannot execute transfer with an unresolved recipient.');
        }
      }

      if (act.type == PlannedActionType.reserve ||
          act.type == PlannedActionType.allocate) {
        if (act.destinationId == 'unknown' ||
            act.destinationName.toLowerCase() == 'reserve' ||
            act.destinationName.isEmpty) {
          errors.add(
              'Cannot execute reserve allocation with an unresolved destination.');
        }
      }
    }

    // 4. Single-wallet balance sufficiency check (only if multi-wallet funding is NOT active)
    final isMultiWalletFunded = plan.selectedFundingCurrency != null &&
        plan.selectedFundingCurrency != Currency.usd &&
        plan.shortfall != null &&
        plan.shortfall!.minorUnits > 0;

    if (!isMultiWalletFunded && plan.validation.errors.isEmpty) {
      final usdWallet =
          await contextService.getWalletForCurrency(Currency.usd);
      final availableBalance =
          usdWallet?.balance ?? Money.zero(Currency.usd);

      final totalRequired = plan.totalDebit.minorUnits + plan.totalFee.minorUnits;

      if (totalRequired > availableBalance.minorUnits) {
        errors.add(
          'You don\'t have enough ${Currency.usd.code} to complete this plan. Available: ${availableBalance.toFormattedString()}, Requested: ${plan.totalDebit.toFormattedString()} (plus ${plan.totalFee.toFormattedString()} network fee).',
        );
      }
    }

    if (errors.isNotEmpty) {
      return PlanValidationResult.invalid(errors, warnings: warnings);
    }

    return PlanValidationResult.valid(warnings: warnings);
  }
}

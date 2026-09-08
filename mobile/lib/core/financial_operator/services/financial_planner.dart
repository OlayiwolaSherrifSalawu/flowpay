import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/financial_entities.dart';
import '../models/financial_intent_types.dart';
import '../models/financial_plan_models.dart';
import 'financial_context_service.dart';
import 'financial_policy_validator.dart';

/// FlowPay Financial Planner
/// Compiles a fully resolved StructuredIntent into a deterministic FinancialPlan,
/// calculating debit totals, fees, and projected post-execution balance changes.
class FinancialPlanner {
  final FinancialContextService contextService;

  FinancialPlanner({required this.contextService});

  /// Generate a structured FinancialPlan from a resolved StructuredIntent
  Future<FinancialPlan> createPlan(StructuredIntent intent) async {
    final planId =
        'plan_${DateTime.now().millisecondsSinceEpoch}_${intent.id.substring(intent.id.length - 4)}';
    final plannedActions = <PlannedFinancialAction>[];

    final usdWallet =
        await contextService.getWalletForCurrency(Currency.usd);
    final sourceWalletId = usdWallet?.id ?? 'sw_demo_usdb_01';
    const sourceWalletName = 'USD Wallet (USDB)';

    int totalDebitMinor = 0;
    int totalFeeMinor = 0;

    for (int i = 0; i < intent.actions.length; i++) {
      final act = intent.actions[i];

      // Resolved amount
      final amount = act.amount.resolvedAmount ??
          act.amount.fixedAmount ??
          Money.zero(act.amount.currency);

      totalDebitMinor += amount.minorUnits;

      // Planned action type
      PlannedActionType plannedType = PlannedActionType.send;
      String destId = 'unknown';
      String destName = 'Unknown';
      String destType = 'unknown';
      Money fee = Money.zero(amount.currency);

      if (act.intentType == FinancialIntentType.sendMoney ||
          act.intentType == FinancialIntentType.payBeneficiary) {
        plannedType = PlannedActionType.send;
        destId = act.person?.resolvedBeneficiary?.id ?? 'recipient';
        destName = act.person?.displayName ?? 'Recipient';
        destType = 'beneficiary';
        // Minor network fee: e.g. 10 cents
        fee = Money.fromMinor(10, amount.currency);
        totalFeeMinor += 10;
      } else if (act.intentType == FinancialIntentType.createReserve ||
          act.intentType == FinancialIntentType.updateReserve) {
        plannedType = PlannedActionType.reserve;
        destId = act.destination?.resolvedWalletId ?? 'reserve';
        destName = act.destination?.displayName ?? 'Reserve';
        destType = 'reserve';
      } else if (act.intentType == FinancialIntentType.allocateMoney) {
        plannedType = PlannedActionType.allocate;
        destId = act.destination?.resolvedWalletId ?? 'savings';
        destName = act.destination?.displayName ?? 'Savings';
        destType = 'wallet';
      } else if (act.intentType == FinancialIntentType.convertCurrency) {
        plannedType = PlannedActionType.convert;
        destId = 'fx_conversion';
        destName = 'Currency Swap';
        destType = 'fx';
      }

      plannedActions.add(
        PlannedFinancialAction(
          id: 'item_${planId}_${i + 1}',
          type: plannedType,
          amount: amount,
          percentageLabel: act.amount.type == AmountType.percentage &&
                  act.amount.percentage != null
              ? '${act.amount.percentage!.toStringAsFixed(0)}%'
              : null,
          sourceWalletId: sourceWalletId,
          sourceWalletName: sourceWalletName,
          destinationId: destId,
          destinationName: destName,
          destinationType: destType,
          description: act.description,
          fee: fee,
        ),
      );
    }

    final totalDebit = Money.fromMinor(totalDebitMinor, Currency.usd);
    final totalFee = Money.fromMinor(totalFeeMinor, Currency.usd);

    // Compute expected balance changes
    final currentBalance = usdWallet?.balance ??
        Money.fromMajorString('24500.00', Currency.usd);
    final projectedBalance =
        currentBalance.minorUnits >= (totalDebitMinor + totalFeeMinor)
            ? Money.fromMinor(
                currentBalance.minorUnits - (totalDebitMinor + totalFeeMinor),
                Currency.usd)
            : Money.fromMinor(
                currentBalance.minorUnits - (totalDebitMinor + totalFeeMinor),
                Currency.usd);

    final balanceImpacts = <BalanceImpact>[
      BalanceImpact(
        walletId: sourceWalletId,
        walletName: sourceWalletName,
        currency: Currency.usd,
        currentBalance: currentBalance,
        projectedBalance: projectedBalance,
        delta: Money.fromMinor(-(totalDebitMinor + totalFeeMinor), Currency.usd),
      ),
    ];

    // For any reserve / savings action, show positive credit impact
    for (final act in plannedActions) {
      if (act.type == PlannedActionType.reserve ||
          act.type == PlannedActionType.allocate) {
        balanceImpacts.add(
          BalanceImpact(
            walletId: act.destinationId,
            walletName: act.destinationName,
            currency: act.amount.currency,
            currentBalance: Money.zero(act.amount.currency),
            projectedBalance: act.amount,
            delta: act.amount,
          ),
        );
      }
    }

    // Build plan draft
    final draftPlan = FinancialPlan(
      planId: planId,
      title: _generatePlanTitle(plannedActions, totalDebit),
      summary: _generatePlanSummary(plannedActions),
      actions: plannedActions,
      totalDebit: totalDebit,
      totalFee: totalFee,
      expectedBalanceChanges: balanceImpacts,
      validation: const PlanValidationResult(isValid: true),
      createdAt: DateTime.now(),
      executionState: 'READY_FOR_REVIEW',
    );

    // Deterministically validate policy
    final validation =
        await FinancialPolicyValidator.validate(draftPlan, contextService);

    return draftPlan.copyWith(validation: validation);
  }

  static String _generatePlanTitle(
      List<PlannedFinancialAction> actions, Money total) {
    if (actions.length == 1) {
      return '${actions.first.type.displayName} ${actions.first.amount.toFormattedString()}';
    }
    return '${total.toFormattedString()} Multi-Action Plan (${actions.length} steps)';
  }

  static String _generatePlanSummary(List<PlannedFinancialAction> actions) {
    final buffer = StringBuffer();
    for (int i = 0; i < actions.length; i++) {
      final act = actions[i];
      buffer.write('${i + 1}. ${act.type.displayName} ${act.amount.toFormattedString()} to ${act.destinationName}');
      if (i < actions.length - 1) buffer.write(' • ');
    }
    return buffer.toString();
  }
}

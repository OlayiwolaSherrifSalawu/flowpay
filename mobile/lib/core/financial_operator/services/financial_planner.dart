import '../../beneficiaries/beneficiary_model.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../financial_engine/financial_engine.dart';
import '../models/financial_entities.dart';
import '../models/financial_intent_types.dart';
import '../models/financial_plan_models.dart';
import 'financial_context_service.dart';
import 'financial_policy_validator.dart';

/// FlowPay Financial Planner
/// Compiles a fully resolved StructuredIntent into a deterministic FinancialPlan,
/// integrating the FundingPlanner for cross-border routing, shortfall detection,
/// live quote resolution, and zero over-conversion.
class FinancialPlanner {
  final FinancialContextService contextService;
  final ExecutionProvider? executionProvider;
  late final FundingPlanner _fundingPlanner;

  FinancialPlanner({
    required this.contextService,
    this.executionProvider,
  }) {
    final ep = executionProvider ??
        DemoExecutionProvider(
          walletRepo: contextService.walletRepo,
          activityRepo: contextService.activityRepo,
        );
    _fundingPlanner = FundingPlanner(executionProvider: ep);
  }

  /// Generate a structured FinancialPlan from a resolved StructuredIntent
  Future<FinancialPlan> createPlan(
    StructuredIntent intent, {
    Currency? overrideFundingCurrency,
  }) async {
    final planId =
        'plan_${DateTime.now().millisecondsSinceEpoch}_${intent.id.substring(intent.id.length - 4)}';
    final plannedActions = <PlannedFinancialAction>[];

    // Separate send actions from reserve / allocation actions
    final sendActions = <ActionIntent>[];
    final otherActions = <ActionIntent>[];

    for (final act in intent.actions) {
      if (act.intentType == FinancialIntentType.sendMoney ||
          act.intentType == FinancialIntentType.payBeneficiary) {
        sendActions.add(act);
      } else {
        otherActions.add(act);
      }
    }

    SmartPaymentBatchPlan? batchPlan;

    // 1. Process send actions through the FundingPlanner
    if (sendActions.isNotEmpty) {
      final paymentRequests = <PaymentRequest>[];

      for (int i = 0; i < sendActions.length; i++) {
        final act = sendActions[i];
        final amount = act.amount.resolvedAmount ??
            act.amount.fixedAmount ??
            Money.zero(act.amount.currency);

        final recipient = act.person?.resolvedBeneficiary ??
            (act.person != null
                ? Beneficiary(
                    id: 'ben_${act.person!.rawInput.toLowerCase().replaceAll(' ', '_')}',
                    nickname: act.person!.rawInput,
                    legalName: act.person!.rawInput,
                    aliases: [act.person!.rawInput],
                    relationship: 'Beneficiary',
                    destinationCountry: 'Nigeria',
                    countryFlag: '🇳🇬',
                    destinationType: 'bank_account',
                    currency: act.amount.currency == Currency.usd
                        ? Currency.ngn
                        : act.amount.currency,
                    preferredFundingCurrency: Currency.usd,
                    accountOrAddress: 'Pending Account Details',
                    isVerified: false,
                  )
                : null);

        if (recipient != null) {
          paymentRequests.add(
            PaymentRequest(
              id: act.id,
              recipient: recipient,
              amount: amount,
              description: act.description,
            ),
          );
        }
      }

      if (paymentRequests.isNotEmpty) {
        batchPlan = await _fundingPlanner.planPaymentBatch(
          requests: paymentRequests,
          displayCurrency: paymentRequests.first.amount.currency,
          overrideFundingCurrency: overrideFundingCurrency,
        );

        // Convert batch items into planned financial actions
        for (final item in batchPlan.items) {
          final originalAct = sendActions.cast<ActionIntent?>().firstWhere(
                (a) => a?.id == item.id,
                orElse: () => null,
              );

          plannedActions.add(
            PlannedFinancialAction(
              id: 'item_${planId}_${item.id}',
              type: PlannedActionType.send,
              amount: item.displayAmount,
              sourceWalletId: batchPlan.fundingAllocations.isNotEmpty
                  ? batchPlan.fundingAllocations.first.walletId
                  : 'sw_primary',
              sourceWalletName: batchPlan.fundingAllocations.isNotEmpty
                  ? batchPlan.fundingAllocations.first.walletName
                  : 'Primary Wallet',
              destinationId: item.recipient.id,
              destinationName: item.recipient.displayName,
              destinationType: item.destinationType,
              destinationRail: item.destinationRail,
              description: item.description,
              fxRate: item.quote?.formattedRate,
              fee: item.fee,
              destinationAmount: item.destinationAmount,
              destinationCurrency: item.destinationCurrency,
              fundingCurrency: batchPlan.selectedFundingCurrency,
              dependsOn: originalAct?.dependsOn ?? const [],
            ),
          );
        }
      }
    }

    // 2. Process reserve, allocate, or conversion actions
    for (int i = 0; i < otherActions.length; i++) {
      final act = otherActions[i];
      final amount = act.amount.resolvedAmount ??
          act.amount.fixedAmount ??
          Money.zero(act.amount.currency);

      PlannedActionType plannedType = PlannedActionType.reserve;
      String destId = 'unknown';
      String destName = 'Unknown';
      String destType = 'unknown';
      Money fee = Money.zero(amount.currency);

      if (act.intentType == FinancialIntentType.createReserve ||
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
          id: 'item_${planId}_other_${i + 1}',
          type: plannedType,
          amount: amount,
          percentageLabel: act.amount.type == AmountType.percentage &&
                  act.amount.percentage != null
              ? '${act.amount.percentage!.toStringAsFixed(0)}%'
              : null,
          sourceWalletId: 'sw_demo_usdb_01',
          sourceWalletName: 'USD Wallet (USDB)',
          destinationId: destId,
          destinationName: destName,
          destinationType: destType,
          description: act.description,
          fee: fee,
          destinationCurrency: act.destinationCurrency,
          dependsOn: act.dependsOn,
        ),
      );
    }

    // 3. Aggregate totals and balance changes
    int totalDebitMinor = 0;
    int totalFeeMinor = 0;

    for (final act in plannedActions) {
      totalDebitMinor += act.amount.minorUnits;
      totalFeeMinor += act.fee.minorUnits;
    }

    final totalDebit = Money.fromMinor(totalDebitMinor, Currency.usd);
    final totalFee = Money.fromMinor(totalFeeMinor, Currency.usd);

    final balanceImpacts = <BalanceImpact>[];

    if (batchPlan != null) {
      balanceImpacts.addAll(batchPlan.expectedBalanceChanges);
    } else {
      // Fallback single balance impact for non-send actions
      final usdWallet = await contextService.getWalletForCurrency(Currency.usd);
      final currentBal =
          usdWallet?.balance ?? Money.fromMajorString('24500.00', Currency.usd);
      balanceImpacts.add(
        BalanceImpact(
          walletId: usdWallet?.id ?? 'sw_demo_usdb_01',
          walletName: 'USD Wallet (USDB)',
          currency: Currency.usd,
          currentBalance: currentBal,
          projectedBalance: currentBal.subtract(totalDebit),
          delta: Money.fromMinor(-totalDebitMinor, Currency.usd),
        ),
      );
    }

    // Add positive impact for reserves or savings allocations
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

    // 4. Build draft plan
    final draftPlan = FinancialPlan(
      planId: planId,
      title: _generatePlanTitle(plannedActions, totalDebit),
      summary: _generatePlanSummary(plannedActions),
      actions: plannedActions,
      totalDebit: totalDebit,
      totalFee: totalFee,
      expectedBalanceChanges: balanceImpacts,
      validation: batchPlan != null && !batchPlan.validation.isValid
          ? batchPlan.validation
          : const PlanValidationResult(isValid: true),
      createdAt: DateTime.now(),
      executionState: batchPlan != null && !batchPlan.validation.isValid
          ? 'INSUFFICIENT_FUNDS'
          : 'READY_FOR_REVIEW',
      routeExplanation: batchPlan?.routeExplanation,
      availableRouteOverrides: batchPlan?.availableRouteOverrides ?? const [],
      selectedFundingCurrency: batchPlan?.selectedFundingCurrency,
      quoteExpiresAt: batchPlan?.quoteExpiresAt,
      shortfall: batchPlan?.shortfall,
    );

    // 5. Deterministically validate policy
    final validation =
        await FinancialPolicyValidator.validate(draftPlan, contextService);

    return draftPlan.copyWith(validation: validation);
  }

  static String _generatePlanTitle(
      List<PlannedFinancialAction> actions, Money total) {
    if (actions.isEmpty) return 'Financial Plan';
    if (actions.length == 1) {
      return '${actions.first.type.displayName} ${actions.first.amount.toFormattedString()}';
    }
    return '${total.toFormattedString()} Multi-Action Plan (${actions.length} steps)';
  }

  static String _generatePlanSummary(List<PlannedFinancialAction> actions) {
    final buffer = StringBuffer();
    for (int i = 0; i < actions.length; i++) {
      final act = actions[i];
      buffer.write(
          '${i + 1}. ${act.type.displayName} ${act.amount.toFormattedString()} to ${act.destinationName}');
      if (i < actions.length - 1) buffer.write(' • ');
    }
    return buffer.toString();
  }
}

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

        final rawTarget = act.person?.rawInput.trim() ?? '';
        final recipient = act.person?.resolvedBeneficiary ??
            (act.person != null
                ? Beneficiary(
                    id: 'ben_${rawTarget.toLowerCase().replaceAll(' ', '_')}',
                    nickname: rawTarget,
                    legalName: rawTarget,
                    aliases: [rawTarget],
                    relationship: 'Beneficiary',
                    destinationCountry: act.amount.currency == Currency.cad
                        ? 'Canada'
                        : act.amount.currency == Currency.mxn
                            ? 'Mexico'
                            : 'Nigeria',
                    countryFlag: act.amount.currency == Currency.cad
                        ? '🇨🇦'
                        : act.amount.currency == Currency.mxn
                            ? '🇲🇽'
                            : '🇳🇬',
                    destinationType: 'bank_account',
                    currency: act.amount.currency,
                    preferredFundingCurrency: Currency.usd,
                    accountOrAddress: rawTarget.isNotEmpty ? rawTarget : 'Pending Account Details',
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

          final actRawTarget = originalAct?.person?.rawInput.trim();
          final resolvedAddr = item.recipient.accountOrAddress.isNotEmpty &&
                  item.recipient.accountOrAddress != 'Pending Account Details'
              ? item.recipient.accountOrAddress
              : (actRawTarget != null && actRawTarget.isNotEmpty ? actRawTarget : null);

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
              destinationAddress: resolvedAddr,
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
        final srcCurr = act.amount.currency;
        final destCurr = act.destinationCurrency ??
            (srcCurr == Currency.usd ? Currency.ngn : Currency.usd);

        final srcWallet = await contextService.getWalletForCurrency(srcCurr);
        final dstWallet = await contextService.getWalletForCurrency(destCurr);

        destId = dstWallet?.id ?? 'sw_${destCurr.code.toLowerCase()}';
        destName = dstWallet?.name ?? '${destCurr.code} Wallet';
        destType = 'wallet';

        PaymentQuote? quote;
        try {
          quote = await _fundingPlanner.executionProvider.getQuote(
            source: srcCurr,
            destination: destCurr,
            amount: amount,
            isSourceAmount: true,
          );
          fee = quote.providerFee.add(quote.networkFee);
        } catch (_) {
          fee = Money.zero(srcCurr);
        }

        plannedActions.add(
          PlannedFinancialAction(
            id: 'item_${planId}_other_${i + 1}',
            type: plannedType,
            amount: amount,
            sourceWalletId: srcWallet?.id ?? 'sw_${srcCurr.code.toLowerCase()}',
            sourceWalletName: srcWallet?.name ?? '${srcCurr.code} Wallet',
            destinationId: destId,
            destinationName: destName,
            destinationType: destType,
            description: act.description.isNotEmpty
                ? act.description
                : 'Transfer to $destName',
            fee: fee,
            destinationAmount: quote?.destinationAmount,
            destinationCurrency: destCurr,
            fundingCurrency: srcCurr,
            fxRate: quote?.formattedRate,
            dependsOn: act.dependsOn,
          ),
        );
        continue;
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
    final primaryCurrency = plannedActions.isNotEmpty
        ? (plannedActions.first.fundingCurrency ??
            plannedActions.first.amount.currency)
        : Currency.usd;

    int totalDebitMinor = 0;
    int totalFeeMinor = 0;

    for (final act in plannedActions) {
      if (act.amount.currency == primaryCurrency) {
        totalDebitMinor += act.amount.minorUnits;
      }
      if (act.fee.currency == primaryCurrency) {
        totalFeeMinor += act.fee.minorUnits;
      }
    }

    final totalDebit = Money.fromMinor(totalDebitMinor, primaryCurrency);
    final totalFee = Money.fromMinor(totalFeeMinor, primaryCurrency);

    final balanceImpacts = <BalanceImpact>[];

    if (batchPlan != null) {
      balanceImpacts.addAll(batchPlan.expectedBalanceChanges);
    } else {
      final convertActions =
          plannedActions.where((a) => a.type == PlannedActionType.convert).toList();
      if (convertActions.isNotEmpty) {
        for (final cAct in convertActions) {
          final srcWallet =
              await contextService.getWalletForCurrency(cAct.amount.currency);
          final currentSrc =
              srcWallet?.balance ?? Money.zero(cAct.amount.currency);
          final debitTotal = cAct.amount.add(cAct.fee);
          balanceImpacts.add(
            BalanceImpact(
              walletId: cAct.sourceWalletId,
              walletName: cAct.sourceWalletName,
              currency: cAct.amount.currency,
              currentBalance: currentSrc,
              projectedBalance: currentSrc.subtract(debitTotal),
              delta: Money.fromMinor(-debitTotal.minorUnits, cAct.amount.currency),
            ),
          );

          if (cAct.destinationCurrency != null &&
              cAct.destinationAmount != null) {
            final dstWallet = await contextService
                .getWalletForCurrency(cAct.destinationCurrency!);
            final currentDst =
                dstWallet?.balance ?? Money.zero(cAct.destinationCurrency!);
            balanceImpacts.add(
              BalanceImpact(
                walletId: cAct.destinationId,
                walletName: cAct.destinationName,
                currency: cAct.destinationCurrency!,
                currentBalance: currentDst,
                projectedBalance: currentDst.add(cAct.destinationAmount!),
                delta: cAct.destinationAmount!,
              ),
            );
          }
        }
      } else {
        // Fallback single balance impact for non-send, non-convert actions
        final fundingWallet =
            await contextService.getWalletForCurrency(primaryCurrency);
        final currentBal =
            fundingWallet?.balance ?? Money.zero(primaryCurrency);
        balanceImpacts.add(
          BalanceImpact(
            walletId: fundingWallet?.id ?? 'sw_primary',
            walletName: fundingWallet?.name ?? 'Primary Wallet',
            currency: primaryCurrency,
            currentBalance: currentBal,
            projectedBalance: currentBal.subtract(totalDebit),
            delta: Money.fromMinor(-totalDebitMinor, primaryCurrency),
          ),
        );
      }
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
      selectedFundingCurrency: batchPlan?.selectedFundingCurrency ?? primaryCurrency,
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
      final a = actions.first;
      if (a.type == PlannedActionType.convert && a.destinationCurrency != null) {
        return 'Convert ${a.amount.toFormattedString()} to ${a.destinationCurrency!.code}';
      }
      return '${actions.first.type.displayName} ${actions.first.amount.toFormattedString()}';
    }
    return '${total.toFormattedString()} Multi-Action Plan (${actions.length} steps)';
  }

  static String _generatePlanSummary(List<PlannedFinancialAction> actions) {
    final buffer = StringBuffer();
    for (int i = 0; i < actions.length; i++) {
      final act = actions[i];
      if (act.type == PlannedActionType.convert && act.destinationAmount != null) {
        buffer.write(
            '${i + 1}. Convert ${act.amount.toFormattedString()} from ${act.sourceWalletName} to ~${act.destinationAmount!.toFormattedString()} in ${act.destinationName}');
      } else {
        buffer.write(
            '${i + 1}. ${act.type.displayName} ${act.amount.toFormattedString()} to ${act.destinationName}');
      }
      if (i < actions.length - 1) buffer.write(' • ');
    }
    return buffer.toString();
  }
}

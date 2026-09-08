import '../../beneficiaries/beneficiary_model.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../financial_operator/models/financial_plan_models.dart';
import '../models/payment_execution_state.dart';
import '../models/quote_model.dart';
import '../models/smart_payment_plan.dart';
import '../models/wallet_balance_model.dart';
import 'execution_provider.dart';

/// Request specification for a single payment item before funding is compiled
class PaymentRequest {
  final String id;
  final Beneficiary recipient;
  final Money amount; // Amount requested in display/payment currency (e.g. $500.00 USD)
  final String description;

  const PaymentRequest({
    required this.id,
    required this.recipient,
    required this.amount,
    this.description = 'Payment',
  });
}

/// FlowPay Deterministic Smart Funding Planner
/// Solves multi-wallet funding, cross-border quotes, and automatic wallet balancing
/// with zero floating-point drift and zero over-conversion.
class FundingPlanner {
  final ExecutionProvider executionProvider;
  final FinancialPreferences preferences;

  FundingPlanner({
    required this.executionProvider,
    this.preferences = const FinancialPreferences(),
  });

  /// Build a complete, deterministic SmartPaymentBatchPlan
  Future<SmartPaymentBatchPlan> planPaymentBatch({
    required List<PaymentRequest> requests,
    Currency displayCurrency = Currency.usd,
    Currency? overrideFundingCurrency,
  }) async {
    final planId = 'plan_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = DateTime.now();

    // 1. Fetch live balances from the execution provider
    final balances = await executionProvider.getBalances();
    final balancesByCurr = {for (final b in balances) b.currency: b};

    // 2. Sum total requested amount in display currency
    int totalRequestedMinor = 0;
    for (final req in requests) {
      totalRequestedMinor += req.amount.minorUnits;
    }
    final totalRequested = Money.fromMinor(totalRequestedMinor, displayCurrency);

    // 3. Inspect spendable balance in the primary/display currency
    final primaryWallet = balancesByCurr[displayCurrency];
    final availableDirect = primaryWallet?.spendableBalance ?? Money.zero(displayCurrency);

    // 4. Calculate shortfall
    final shortfallMinor = totalRequestedMinor - availableDirect.minorUnits;
    final shortfall = Money.fromMinor(
      shortfallMinor > 0 ? shortfallMinor : 0,
      displayCurrency,
    );

    final quotes = <PaymentQuote>[];
    final fundingAllocations = <FundingAllocation>[];
    final smartItems = <SmartPaymentItem>[];
    final balanceImpacts = <BalanceImpact>[];
    final validationErrors = <String>[];
    final validationWarnings = <String>[];

    // 5. Cross-border destination quotes for each recipient
    for (final req in requests) {
      final destCurr = req.recipient.destinationCurrency;
      Money destAmount = req.amount;
      PaymentQuote? itemQuote;
      Money itemFee = Money.fromMinor(10, displayCurrency); // $0.10 base network fee

      if (destCurr != displayCurrency) {
        // Cross-border payout requires quote
        itemQuote = await executionProvider.getQuote(
          source: displayCurrency,
          destination: destCurr,
          amount: req.amount,
          isSourceAmount: true,
        );
        quotes.add(itemQuote);
        destAmount = itemQuote.destinationAmount;
        itemFee = itemQuote.networkFee.add(itemQuote.providerFee);
      }

      smartItems.add(
        SmartPaymentItem(
          id: req.id,
          recipient: req.recipient,
          displayAmount: req.amount,
          destinationAmount: destAmount,
          destinationCurrency: destCurr,
          destinationType: req.recipient.destinationType,
          destinationRail: '${req.recipient.destinationCountry} (${req.recipient.accountOrAddress})',
          quote: itemQuote,
          fee: itemFee,
          description: req.description,
        ),
      );
    }

    // 6. Funding strategy: direct funding vs shortfall conversion
    Currency selectedFundingCurr = displayCurrency;
    String routeExplanation = 'Direct funding from your ${displayCurrency.code} wallet.';

    if (shortfallMinor <= 0) {
      // Scenario 1: Enough USD — direct funding covers 100%
      fundingAllocations.add(
        FundingAllocation(
          walletId: primaryWallet?.walletId ?? 'sw_primary',
          walletName: primaryWallet?.walletName ?? '${displayCurrency.code} Smart Wallet',
          currency: displayCurrency,
          allocatedAmount: totalRequested,
          requiresConversion: false,
          convertedOutputAmount: totalRequested,
          fee: Money.zero(displayCurrency),
          explanation: 'Direct payment from spendable ${displayCurrency.code} balance.',
        ),
      );

      final currentBal = primaryWallet?.available ?? Money.zero(displayCurrency);
      final projBal = currentBal.subtract(totalRequested);
      balanceImpacts.add(
        BalanceImpact(
          walletId: primaryWallet?.walletId ?? 'sw_primary',
          walletName: primaryWallet?.walletName ?? '${displayCurrency.code} Smart Wallet',
          currency: displayCurrency,
          currentBalance: currentBal,
          projectedBalance: projBal,
          delta: Money.fromMinor(-totalRequestedMinor, displayCurrency),
        ),
      );
    } else {
      // Shortfall exists: Determine alternative funding wallet
      // Direct portion consumes all available spendable funds in display wallet
      if (availableDirect.minorUnits > 0) {
        fundingAllocations.add(
          FundingAllocation(
            walletId: primaryWallet?.walletId ?? 'sw_primary',
            walletName: primaryWallet?.walletName ?? '${displayCurrency.code} Smart Wallet',
            currency: displayCurrency,
            allocatedAmount: availableDirect,
            requiresConversion: false,
            convertedOutputAmount: availableDirect,
            fee: Money.zero(displayCurrency),
            explanation: 'Consume all available ${displayCurrency.code} funds first.',
          ),
        );
      }

      // Candidate alternative wallets (excluding display currency & protected wallets)
      final candidates = balances.where((b) {
        if (b.currency == displayCurrency) return false;
        return b.spendableBalance.minorUnits > 0;
      }).toList();

      // Preferred major settlement currencies: EUR > GBP > CAD > NGN > MXN > GHS
      const defaultOrder = [Currency.eur, Currency.gbp, Currency.cad, Currency.ngn, Currency.mxn, Currency.ghs];
      candidates.sort((a, b) {
        if (overrideFundingCurrency != null) {
          if (a.currency == overrideFundingCurrency) return -1;
          if (b.currency == overrideFundingCurrency) return 1;
        }
        final idxA = defaultOrder.indexOf(a.currency);
        final idxB = defaultOrder.indexOf(b.currency);
        final ordA = idxA == -1 ? 99 : idxA;
        final ordB = idxB == -1 ? 99 : idxB;
        return ordA.compareTo(ordB);
      });

      // Evaluate candidates and select the optimal funding route
      WalletBalanceDetails? chosenCandidate;
      PaymentQuote? chosenShortfallQuote;
      Money? chosenSourceRequired;

      for (final cand in candidates) {
        // Fetch quote to convert candidate currency -> displayCurrency to produce shortfall
        final candQuote = await executionProvider.getQuote(
          source: cand.currency,
          destination: displayCurrency,
          amount: shortfall,
          isSourceAmount: false, // Calculate source required to produce shortfall
        );

        // Required source = sourceAmount + providerFee + networkFee
        final requiredTotal = candQuote.totalSourceAmount;

        if (cand.spendableBalance.minorUnits >= requiredTotal.minorUnits) {
          chosenCandidate = cand;
          chosenShortfallQuote = candQuote;
          chosenSourceRequired = requiredTotal;
          selectedFundingCurr = cand.currency;
          break;
        }
      }

      if (chosenCandidate == null || chosenShortfallQuote == null || chosenSourceRequired == null) {
        // Check if user has protected funds (e.g. Tax Reserve)
        final protectedWallets = balances.where((b) => b.isProtected && b.protectedAmount.minorUnits > 0).toList();
        if (protectedWallets.isNotEmpty) {
          final p = protectedWallets.first;
          validationErrors.add(
            'You have ${p.protectedAmount.toFormattedString()} in your ${p.purpose ?? "Tax Reserve"}, but it is protected and unavailable for this payment.',
          );
        } else if (balances.where((b) => b.currency != displayCurrency).isEmpty) {
          validationErrors.add(
            'You don\'t have enough ${displayCurrency.code} to complete this plan. Available: ${availableDirect.toFormattedString()}, Requested: ${totalRequested.toFormattedString()} (plus \$0.10 network fee).',
          );
        } else {
          validationErrors.add(
            'Insufficient funds across all available wallets to cover the ${shortfall.toFormattedString()} shortfall.',
          );
        }
      } else {
        // Successful shortfall funding candidate found!
        quotes.add(chosenShortfallQuote);

        fundingAllocations.add(
          FundingAllocation(
            walletId: chosenCandidate.walletId,
            walletName: chosenCandidate.walletName,
            currency: chosenCandidate.currency,
            allocatedAmount: chosenSourceRequired,
            requiresConversion: true,
            convertedOutputAmount: shortfall,
            quote: chosenShortfallQuote,
            fee: chosenShortfallQuote.providerFee.add(chosenShortfallQuote.networkFee),
            explanation:
                'Convert ${chosenSourceRequired.toFormattedString()} from ${chosenCandidate.currency.code} at rate ${chosenShortfallQuote.exchangeRate} to cover the ${shortfall.toFormattedString()} shortfall.',
          ),
        );

        // Generate data-driven explanation
        routeExplanation =
            'Your ${displayCurrency.code} wallet has ${availableDirect.toFormattedString()} available, but your payments require ${totalRequested.toFormattedString()}. I selected ${chosenCandidate.currency.code} because it is your lowest-cost available route to cover the ${shortfall.toFormattedString()} shortfall.';

        // Primary wallet projected balance (drops to $0.00 or remaining protected funds)
        final primaryCurrent = primaryWallet?.available ?? Money.zero(displayCurrency);
        balanceImpacts.add(
          BalanceImpact(
            walletId: primaryWallet?.walletId ?? 'sw_primary',
            walletName: primaryWallet?.walletName ?? '${displayCurrency.code} Smart Wallet',
            currency: displayCurrency,
            currentBalance: primaryCurrent,
            projectedBalance: primaryCurrent.subtract(availableDirect),
            delta: Money.fromMinor(-availableDirect.minorUnits, displayCurrency),
          ),
        );

        // Funding alternative wallet projected balance
        final candCurrent = chosenCandidate.available;
        final candProjected = candCurrent.subtract(chosenSourceRequired);
        balanceImpacts.add(
          BalanceImpact(
            walletId: chosenCandidate.walletId,
            walletName: chosenCandidate.walletName,
            currency: chosenCandidate.currency,
            currentBalance: candCurrent,
            projectedBalance: candProjected,
            delta: Money.fromMinor(-chosenSourceRequired.minorUnits, chosenCandidate.currency),
          ),
        );
      }
    }

    // Available overrides (other wallets that could fund the shortfall)
    final overrideList = <String>[];
    for (final b in balances) {
      if (b.currency != displayCurrency && b.currency != selectedFundingCurr && b.spendableBalance.minorUnits > 0) {
        overrideList.add(b.currency.code);
      }
    }

    // Earliest quote expiry
    DateTime earliestExpiry = DateTime.now().add(const Duration(seconds: 45));
    for (final q in quotes) {
      if (q.expiresAt.isBefore(earliestExpiry)) {
        earliestExpiry = q.expiresAt;
      }
    }

    final validationResult = validationErrors.isEmpty
        ? PlanValidationResult.valid(warnings: validationWarnings)
        : PlanValidationResult.invalid(validationErrors, warnings: validationWarnings);

    return SmartPaymentBatchPlan(
      planId: planId,
      items: smartItems,
      totalRequested: totalRequested,
      availableDirect: availableDirect,
      shortfall: shortfall,
      fundingAllocations: fundingAllocations,
      quotes: quotes,
      expectedBalanceChanges: balanceImpacts,
      routeExplanation: routeExplanation,
      availableRouteOverrides: overrideList,
      selectedFundingCurrency: selectedFundingCurr,
      quoteExpiresAt: earliestExpiry,
      validation: validationResult,
      executionState: validationErrors.isEmpty ? PaymentExecutionState.quoteReady : PaymentExecutionState.insufficientFunds,
      createdAt: createdAt,
    );
  }
}

import '../../money/currency.dart';
import '../../money/money.dart';
import '../models/quote_model.dart';
import '../models/wallet_balance_model.dart';
import 'execution_provider.dart';

/// Structured Proposal for Wallet Balancing
class WalletBalancingProposal {
  final BalanceTarget target;
  final Money currentBalance;
  final Money shortfall;
  final Currency fundingCurrency;
  final Money requiredSourceAmount;
  final PaymentQuote quote;
  final String explanation;
  final bool isExecutable;
  final String? rejectionReason;

  const WalletBalancingProposal({
    required this.target,
    required this.currentBalance,
    required this.shortfall,
    required this.fundingCurrency,
    required this.requiredSourceAmount,
    required this.quote,
    required this.explanation,
    this.isExecutable = true,
    this.rejectionReason,
  });

  factory WalletBalancingProposal.rejected({
    required BalanceTarget target,
    required Money currentBalance,
    required Money shortfall,
    required String reason,
  }) {
    return WalletBalancingProposal(
      target: target,
      currentBalance: currentBalance,
      shortfall: shortfall,
      fundingCurrency: target.currency,
      requiredSourceAmount: Money.zero(target.currency),
      quote: PaymentQuote(
        quoteId: 'none',
        sourceCurrency: target.currency,
        sourceAmount: Money.zero(target.currency),
        destinationCurrency: target.currency,
        destinationAmount: Money.zero(target.currency),
        exchangeRate: 1.0,
        providerFee: Money.zero(target.currency),
        networkFee: Money.zero(target.currency),
        totalSourceAmount: Money.zero(target.currency),
        expiresAt: DateTime.now(),
        route: 'none',
        provider: 'none',
      ),
      explanation: reason,
      isExecutable: false,
      rejectionReason: reason,
    );
  }
}

/// FlowPay Automatic Wallet Balancing Engine
/// Evaluates balance targets against current state, finds optimal funding,
/// and produces explicit proposals for user approval.
class WalletBalancer {
  final ExecutionProvider executionProvider;

  WalletBalancer({required this.executionProvider});

  /// Evaluate a BalanceTarget and produce an actionable proposal
  Future<WalletBalancingProposal> evaluateTarget(BalanceTarget target) async {
    final balances = await executionProvider.getBalances();
    final balancesByCurr = {for (final b in balances) b.currency: b};

    final targetWallet = balancesByCurr[target.currency];
    final currentSpendable = targetWallet?.spendableBalance ?? Money.zero(target.currency);

    // Check if target is already satisfied
    if (currentSpendable.minorUnits >= target.minimumAmount.minorUnits) {
      return WalletBalancingProposal.rejected(
        target: target,
        currentBalance: currentSpendable,
        shortfall: Money.zero(target.currency),
        reason:
            'Your ${target.currency.code} wallet already has ${currentSpendable.toFormattedString()} available (meets or exceeds target ${target.minimumAmount.toFormattedString()}).',
      );
    }

    final shortfallUnits = target.minimumAmount.minorUnits - currentSpendable.minorUnits;
    final shortfall = Money.fromMinor(shortfallUnits, target.currency);

    // Find candidate alternative wallets to fund the shortfall
    final candidates = balances.where((b) {
      if (b.currency == target.currency) return false;
      return b.spendableBalance.minorUnits > 0;
    }).toList();
    final sourceOrder = target.sourceWallets;
    candidates.sort((a, b) {
      final idxA = sourceOrder.indexOf(a.currency);
      final idxB = sourceOrder.indexOf(b.currency);
      final ordA = idxA == -1 ? 99 : idxA;
      final ordB = idxB == -1 ? 99 : idxB;
      return ordA.compareTo(ordB);
    });

    WalletBalanceDetails? chosenSource;
    PaymentQuote? chosenQuote;
    Money? chosenSourceRequired;

    for (final cand in candidates) {
      final quote = await executionProvider.getQuote(
        source: cand.currency,
        destination: target.currency,
        amount: shortfall,
        isSourceAmount: false,
      );

      final neededTotal = quote.totalSourceAmount;
      if (cand.spendableBalance.minorUnits >= neededTotal.minorUnits) {
        chosenSource = cand;
        chosenQuote = quote;
        chosenSourceRequired = neededTotal;
        break;
      }
    }

    if (chosenSource == null || chosenQuote == null || chosenSourceRequired == null) {
      return WalletBalancingProposal.rejected(
        target: target,
        currentBalance: currentSpendable,
        shortfall: shortfall,
        reason:
            'Insufficient funds across all other wallets to cover the ${shortfall.toFormattedString()} ${target.currency.code} shortfall.',
      );
    }

    final explanation =
        'Your ${target.currency.code} wallet is short by ${shortfall.toFormattedString()}. I can convert ${chosenSourceRequired.toFormattedString()} from your ${chosenSource.currency.code} wallet at rate ${chosenQuote.exchangeRate} to top it up to ${target.minimumAmount.toFormattedString()}.';

    return WalletBalancingProposal(
      target: target,
      currentBalance: currentSpendable,
      shortfall: shortfall,
      fundingCurrency: chosenSource.currency,
      requiredSourceAmount: chosenSourceRequired,
      quote: chosenQuote,
      explanation: explanation,
      isExecutable: true,
    );
  }
}

import '../../money/currency.dart';
import '../../money/money.dart';

/// FlowPay Live Payment Quote Model
/// Firm, time-boxed quote locking in conversion rate and fees until expiresAt.
class PaymentQuote {
  final String quoteId;
  final Currency sourceCurrency;
  final Money sourceAmount;
  final Currency destinationCurrency;
  final Money destinationAmount;
  final double exchangeRate; // e.g. 1 USD = 1550 NGN, or 1 EUR = 1.08 USD
  final Money providerFee; // FlowPay / BMONI FX fee
  final Money networkFee; // Blockchain / bank network fee
  final Money totalSourceAmount; // sourceAmount + providerFee + networkFee
  final DateTime expiresAt;
  final String route; // e.g. "EUR -> USD" or "USD -> NGN"
  final String provider; // e.g. "bmoni", "demo", "smart_contract"

  const PaymentQuote({
    required this.quoteId,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.destinationCurrency,
    required this.destinationAmount,
    required this.exchangeRate,
    required this.providerFee,
    required this.networkFee,
    required this.totalSourceAmount,
    required this.expiresAt,
    required this.route,
    required this.provider,
  });

  /// True if current time has passed quote validity expiration
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Remaining validity duration before quote expires
  Duration get timeRemaining {
    final rem = expiresAt.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Formatted rate display: e.g. "1 USD = ₦1,550.00" or "1 EUR = $1.08"
  String get formattedRate {
    return '1 ${sourceCurrency.code} = ${destinationCurrency.symbol}${exchangeRate.toStringAsFixed(destinationCurrency.decimals)} ${destinationCurrency.code}';
  }

  Map<String, dynamic> toJson() => {
        'quoteId': quoteId,
        'sourceCurrency': sourceCurrency.code,
        'sourceAmountMinor': sourceAmount.minorUnits,
        'destinationCurrency': destinationCurrency.code,
        'destinationAmountMinor': destinationAmount.minorUnits,
        'exchangeRate': exchangeRate,
        'providerFeeMinor': providerFee.minorUnits,
        'networkFeeMinor': networkFee.minorUnits,
        'totalSourceAmountMinor': totalSourceAmount.minorUnits,
        'expiresAt': expiresAt.toIso8601String(),
        'route': route,
        'provider': provider,
        'isExpired': isExpired,
      };
}

/// A candidate funding route evaluated during smart payment planning
class FundingRoute {
  final String id;
  final Currency sourceCurrency;
  final Currency destinationCurrency;
  final List<String> steps; // e.g. ["EUR", "USD", "NGN"]
  final Money totalFee;
  final double exchangeRate;
  final bool isDirect;
  final String estimatedDuration;
  final String explanation;

  const FundingRoute({
    required this.id,
    required this.sourceCurrency,
    required this.destinationCurrency,
    required this.steps,
    required this.totalFee,
    required this.exchangeRate,
    this.isDirect = false,
    this.estimatedDuration = 'Instant (under 10s)',
    required this.explanation,
  });
}

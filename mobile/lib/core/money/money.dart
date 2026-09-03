import 'currency.dart';

class Money {
  /// Amount represented strictly as integer minor units (e.g., $10.50 -> 1050 cents)
  final BigInt amountMinor;
  final Currency currency;

  const Money._({required this.amountMinor, required this.currency});

  factory Money.fromMinor(dynamic minor, Currency currency) {
    if (minor is BigInt) {
      return Money._(amountMinor: minor, currency: currency);
    } else if (minor is int) {
      return Money._(amountMinor: BigInt.from(minor), currency: currency);
    } else if (minor is String) {
      return Money._(amountMinor: BigInt.parse(minor), currency: currency);
    }
    throw ArgumentError('Invalid minor unit type: $minor');
  }

  factory Money.fromMajorString(String majorString, Currency currency) {
    final clean = majorString.replaceAll(',', '').trim();
    final parts = clean.split('.');
    final wholeStr = parts[0].isEmpty ? '0' : parts[0];
    final whole = BigInt.parse(wholeStr);

    var fractionStr = parts.length > 1 ? parts[1] : '';
    if (fractionStr.length > currency.decimals) {
      fractionStr = fractionStr.substring(0, currency.decimals);
    } else {
      fractionStr = fractionStr.padRight(currency.decimals, '0');
    }

    final fraction = fractionStr.isEmpty ? BigInt.zero : BigInt.parse(fractionStr);
    final multiplier = BigInt.from(10).pow(currency.decimals);

    final totalMinor = whole >= BigInt.zero
        ? (whole * multiplier) + fraction
        : (whole * multiplier) - fraction;

    return Money._(amountMinor: totalMinor, currency: currency);
  }

  factory Money.zero(Currency currency) {
    return Money._(amountMinor: BigInt.zero, currency: currency);
  }

  Money add(Money other) {
    _assertMatchingCurrency(other);
    return Money._(amountMinor: amountMinor + other.amountMinor, currency: currency);
  }

  Money subtract(Money other) {
    _assertMatchingCurrency(other);
    return Money._(amountMinor: amountMinor - other.amountMinor, currency: currency);
  }

  Money multiply(int scalar) {
    return Money._(amountMinor: amountMinor * BigInt.from(scalar), currency: currency);
  }

  /// Basis points calculation: 100 bps = 1.00%
  Money multiplyBasisPoints(int bps) {
    return Money._(
      amountMinor: (amountMinor * BigInt.from(bps)) ~/ BigInt.from(10000),
      currency: currency,
    );
  }

  bool isGreaterThan(Money other) {
    _assertMatchingCurrency(other);
    return amountMinor > other.amountMinor;
  }

  bool isLessThan(Money other) {
    _assertMatchingCurrency(other);
    return amountMinor < other.amountMinor;
  }

  bool get isZero => amountMinor == BigInt.zero;
  bool get isPositive => amountMinor > BigInt.zero;

  /// Returns standard major string (e.g., "1250.50")
  String toMajorString() {
    final isNegative = amountMinor < BigInt.zero;
    final absMinor = isNegative ? -amountMinor : amountMinor;
    final multiplier = BigInt.from(10).pow(currency.decimals);

    final whole = absMinor ~/ multiplier;
    final fraction = absMinor % multiplier;

    final fractionStr = fraction.toString().padLeft(currency.decimals, '0');
    return '${isNegative ? '-' : ''}$whole.$fractionStr';
  }

  /// Returns user-facing formatted string with symbol & comma separators (e.g. "$1,250.50" or "₦3,100,000.00")
  String formatFormatted({bool includeSymbol = true}) {
    final majorStr = toMajorString();
    final parts = majorStr.split('.');
    final whole = parts[0];
    final fraction = parts.length > 1 ? parts[1] : '00';

    // Insert commas
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAll(regExp, ',');

    final prefix = includeSymbol ? currency.symbol : '';
    return '$prefix$formattedWhole.$fraction';
  }

  /// Minor units as string for BMONI endpoints expecting integer minor string (e.g. "1050")
  String toBmoniMinorString() => amountMinor.toString();

  void _assertMatchingCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: Cannot operate between ${currency.code} and ${other.currency.code}',
      );
    }
  }

  @override
  String toString() => formatFormatted();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amountMinor == other.amountMinor &&
          currency == other.currency;

  @override
  int get hashCode => amountMinor.hashCode ^ currency.hashCode;
}

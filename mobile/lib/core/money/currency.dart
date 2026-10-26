enum Currency {
  usd(
      code: 'USD',
      symbol: '\$',
      decimals: 2,
      stablecoinToken: 'USD',
      name: 'US Dollar'),
  ngn(
      code: 'NGN',
      symbol: '₦',
      decimals: 2,
      stablecoinToken: 'NGN',
      name: 'Nigerian Naira'),
  mxn(
      code: 'MXN',
      symbol: 'Mex\$',
      decimals: 2,
      stablecoinToken: 'MXN',
      name: 'Mexican Peso'),
  eur(
      code: 'EUR',
      symbol: '€',
      decimals: 2,
      stablecoinToken: 'EUR',
      name: 'Euro'),
  cad(
      code: 'CAD',
      symbol: 'CA\$',
      decimals: 2,
      stablecoinToken: 'CAD',
      name: 'Canadian Dollar'),
  gbp(
      code: 'GBP',
      symbol: '£',
      decimals: 2,
      stablecoinToken: 'GBP',
      name: 'British Pound'),
  ghs(
      code: 'GHS',
      symbol: 'GH₵',
      decimals: 2,
      stablecoinToken: 'GHS',
      name: 'Ghanaian Cedi');

  final String code;
  final String symbol;
  final int decimals;
  /// Stellar asset code for this currency (FlowPay assets use the ISO code).
  final String stablecoinToken;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.decimals,
    required this.stablecoinToken,
    required this.name,
  });

  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => Currency.usd,
    );
  }

  /// Legacy (pre-Stellar) token names still found in stored data.
  static const _legacyTokens = {'USD': 'USD', 'NGN': 'NGN', 'MEXE': 'MXN', 'EURE': 'EUR', 'CAD': 'CAD', 'GBPE': 'GBP'};

  static Currency fromToken(String token) {
    final upper = token.toUpperCase();
    final code = _legacyTokens[upper] ?? upper;
    return Currency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => Currency.usd,
    );
  }

  String get flagEmoji {
    switch (this) {
      case Currency.usd:
        return '🇺🇸';
      case Currency.ngn:
        return '🇳🇬';
      case Currency.mxn:
        return '🇲🇽';
      case Currency.eur:
        return '🇪🇺';
      case Currency.cad:
        return '🇨🇦';
      case Currency.gbp:
        return '🇬🇧';
      case Currency.ghs:
        return '🇬🇭';
    }
  }

  String get flag => flagEmoji;
}

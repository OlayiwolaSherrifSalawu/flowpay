enum Currency {
  usd(code: 'USD', symbol: '\$', decimals: 2, stablecoinToken: 'USDB', name: 'US Dollar'),
  ngn(code: 'NGN', symbol: '₦', decimals: 2, stablecoinToken: 'CNGN', name: 'Nigerian Naira'),
  mxn(code: 'MXN', symbol: 'Mex\$', decimals: 2, stablecoinToken: 'MEXe', name: 'Mexican Peso'),
  eur(code: 'EUR', symbol: '€', decimals: 2, stablecoinToken: 'EURe', name: 'Euro'),
  cad(code: 'CAD', symbol: 'CA\$', decimals: 2, stablecoinToken: 'CADC', name: 'Canadian Dollar'),
  gbp(code: 'GBP', symbol: '£', decimals: 2, stablecoinToken: 'GBPe', name: 'British Pound');

  final String code;
  final String symbol;
  final int decimals;
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

  static Currency fromToken(String token) {
    return Currency.values.firstWhere(
      (c) => c.stablecoinToken.toUpperCase() == token.toUpperCase(),
      orElse: () => Currency.usd,
    );
  }
}

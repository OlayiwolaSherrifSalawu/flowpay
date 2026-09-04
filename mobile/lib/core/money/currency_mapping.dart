/// Central Currency & Stablecoin Mapping Registry for FlowPay & BMONI
///
/// CRITICAL BMONI DIRECTIVE:
/// Smart-wallet calls strictly take the STABLECOIN code, not the fiat currency code:
/// - Nigeria: CNGN (not NGN)
/// - Mexico: MEXe (not MXN)
/// - USA: USDB (not USD)
/// - Canada: CADC (not CAD)
/// - Europe: EURe (not EUR)
/// - UK: GBPe (not GBP)
///
/// Encoded centrally here and must NEVER be inlined or duplicated across screens.
class CurrencyMapping {
  static const Map<String, String> fiatToStablecoin = {
    'NGN': 'CNGN',
    'MXN': 'MEXe',
    'USD': 'USDB',
    'CAD': 'CADC',
    'EUR': 'EURe',
    'GBP': 'GBPe',
  };

  static const Map<String, String> countryToStablecoin = {
    'NG': 'CNGN',
    'MX': 'MEXe',
    'US': 'USDB',
    'CA': 'CADC',
    'EU': 'EURe',
    'GB': 'GBPe',
  };

  static const Map<String, String> countryToFiat = {
    'NG': 'NGN',
    'MX': 'MXN',
    'US': 'USD',
    'CA': 'CAD',
    'EU': 'EUR',
    'GB': 'GBP',
  };

  /// Resolves any fiat code or country code to the required BMONI stablecoin token
  static String toStablecoin(String currencyOrCountry) {
    final upper = currencyOrCountry.trim().toUpperCase();
    if (countryToStablecoin.containsKey(upper)) {
      return countryToStablecoin[upper]!;
    }
    if (fiatToStablecoin.containsKey(upper)) {
      return fiatToStablecoin[upper]!;
    }
    return upper.isEmpty ? 'USDB' : upper;
  }

  /// Resolves country code to default fiat code
  static String toFiat(String countryCode) {
    final upper = countryCode.trim().toUpperCase();
    return countryToFiat[upper] ?? 'USD';
  }
}

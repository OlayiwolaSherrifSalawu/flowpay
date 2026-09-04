/**
 * Currency & Stablecoin Mapping Registry for FlowPay & BMONI rails
 *
 * CRITICAL BMONI DIRECTIVE:
 * Smart-wallet calls strictly take the STABLECOIN code, not the fiat currency code:
 * - Nigeria: CNGN (not NGN)
 * - Mexico: MEXe (not MXN)
 * - USA: USDB (not USD)
 * - Canada: CADC (not CAD)
 * - Europe: EURe (not EUR)
 * - UK: GBPe (not GBP)
 *
 * This mapping is encoded centrally here and must NEVER be inlined or duplicated.
 */

export interface CurrencyMetadata {
  fiat: string;
  stablecoin: string;
  country: string;
  countryName: string;
  symbol: string;
  flag: string;
  name: string;
}

export const CURRENCY_MAPPINGS: Record<string, CurrencyMetadata> = {
  NGN: {
    fiat: 'NGN',
    stablecoin: 'CNGN',
    country: 'NG',
    countryName: 'Nigeria',
    symbol: '₦',
    flag: '🇳🇬',
    name: 'Nigerian Naira',
  },
  MXN: {
    fiat: 'MXN',
    stablecoin: 'MEXe',
    country: 'MX',
    countryName: 'Mexico',
    symbol: 'Mex$',
    flag: '🇲🇽',
    name: 'Mexican Peso',
  },
  USD: {
    fiat: 'USD',
    stablecoin: 'USDB',
    country: 'US',
    countryName: 'United States',
    symbol: '$',
    flag: '🇺🇸',
    name: 'US Dollar',
  },
  CAD: {
    fiat: 'CAD',
    stablecoin: 'CADC',
    country: 'CA',
    countryName: 'Canada',
    symbol: 'CA$',
    flag: '🇨🇦',
    name: 'Canadian Dollar',
  },
  EUR: {
    fiat: 'EUR',
    stablecoin: 'EURe',
    country: 'EU',
    countryName: 'Eurozone',
    symbol: '€',
    flag: '🇪🇺',
    name: 'Euro',
  },
  GBP: {
    fiat: 'GBP',
    stablecoin: 'GBPe',
    country: 'GB',
    countryName: 'United Kingdom',
    symbol: '£',
    flag: '🇬🇧',
    name: 'British Pound',
  },
};

/**
 * Maps any fiat currency code (e.g. "NGN", "MXN") or stablecoin token to its BMONI stablecoin token
 */
export function getStablecoinForCurrency(fiatOrToken: string): string {
  const upper = (fiatOrToken || '').trim().toUpperCase();
  if (upper in CURRENCY_MAPPINGS) {
    return CURRENCY_MAPPINGS[upper].stablecoin;
  }
  for (const item of Object.values(CURRENCY_MAPPINGS)) {
    if (item.stablecoin.toUpperCase() === upper) {
      return item.stablecoin;
    }
  }
  return upper;
}

/**
 * Maps ISO country code (e.g. "NG", "MX") to its BMONI settlement stablecoin token
 */
export function getStablecoinForCountry(countryCode: string): string {
  const upper = (countryCode || '').trim().toUpperCase();
  for (const item of Object.values(CURRENCY_MAPPINGS)) {
    if (item.country.toUpperCase() === upper) {
      return item.stablecoin;
    }
  }
  return 'USDB';
}

/**
 * Maps ISO country code to default fiat currency code
 */
export function getFiatForCountry(countryCode: string): string {
  const upper = (countryCode || '').trim().toUpperCase();
  for (const item of Object.values(CURRENCY_MAPPINGS)) {
    if (item.country.toUpperCase() === upper) {
      return item.fiat;
    }
  }
  return 'USD';
}

/**
 * Maps stablecoin token back to underlying fiat currency
 */
export function getFiatForStablecoin(token: string): string {
  const upper = (token || '').trim().toUpperCase();
  for (const item of Object.values(CURRENCY_MAPPINGS)) {
    if (item.stablecoin.toUpperCase() === upper || item.fiat.toUpperCase() === upper) {
      return item.fiat;
    }
  }
  return 'USD';
}

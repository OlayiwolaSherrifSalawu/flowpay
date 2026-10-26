import { Asset, Networks, StrKey } from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import type { SupportedCurrency } from '../core/money.js';

/**
 * Stellar network + asset registry. Everything money-related in FlowPay resolves
 * a fiat currency (USD, CAD, MXN, GBP, NGN) to a Stellar `Asset` through here.
 */

export type StellarCurrency = Extract<SupportedCurrency, 'USD' | 'CAD' | 'MXN' | 'GBP' | 'NGN'>;

export const STELLAR_CURRENCIES: readonly StellarCurrency[] = ['USD', 'CAD', 'MXN', 'GBP', 'NGN'];

export interface StellarNetworkConfig {
  network: 'testnet' | 'public';
  horizonUrl: string;
  passphrase: string;
  friendbotUrl: string | null;
  explorerBaseUrl: string;
}

export function getNetworkConfig(): StellarNetworkConfig {
  const isTestnet = env.STELLAR_NETWORK === 'testnet';
  return {
    network: env.STELLAR_NETWORK,
    horizonUrl:
      env.STELLAR_HORIZON_URL ?? (isTestnet ? 'https://horizon-testnet.stellar.org' : 'https://horizon.stellar.org'),
    passphrase: isTestnet ? Networks.TESTNET : Networks.PUBLIC,
    friendbotUrl: isTestnet ? env.STELLAR_FRIENDBOT_URL : null,
    explorerBaseUrl: `https://stellar.expert/explorer/${isTestnet ? 'testnet' : 'public'}`,
  };
}

export function explorerTxUrl(hash: string): string {
  return `${getNetworkConfig().explorerBaseUrl}/tx/${hash}`;
}

export function explorerAccountUrl(accountId: string): string {
  return `${getNetworkConfig().explorerBaseUrl}/account/${accountId}`;
}

/**
 * Reference FX (units of currency per 1 USD). Used ONLY to seed testnet liquidity pools
 * in the bootstrap script. Live quotes always come from Horizon path-finding.
 */
export const TESTNET_REFERENCE_RATES_PER_USD: Record<StellarCurrency, string> = {
  USD: '1',
  CAD: '1.375',
  MXN: '17.5',
  GBP: '0.78',
  NGN: '1550',
};

export class StellarConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'StellarConfigError';
  }
}

function assetOverride(currency: StellarCurrency): string | undefined {
  const overrides: Record<StellarCurrency, string | undefined> = {
    USD: env.STELLAR_ASSET_USD,
    CAD: env.STELLAR_ASSET_CAD,
    MXN: env.STELLAR_ASSET_MXN,
    GBP: env.STELLAR_ASSET_GBP,
    NGN: env.STELLAR_ASSET_NGN,
  };
  return overrides[currency];
}

/** Parses "CODE:ISSUER" into an Asset, validating the issuer public key. */
export function parseAssetString(value: string): Asset {
  const [code, issuer] = value.split(':');
  if (!code || !issuer || !StrKey.isValidEd25519PublicKey(issuer)) {
    throw new StellarConfigError(`Invalid Stellar asset "${value}" — expected CODE:G...ISSUER`);
  }
  return new Asset(code, issuer);
}

/**
 * Resolves the Stellar asset for a fiat currency. Throws a StellarConfigError (never
 * guesses) when no issuer is configured — run `npm run stellar:bootstrap` on testnet.
 */
export function assetFor(currency: StellarCurrency): Asset {
  const override = assetOverride(currency);
  if (override) return parseAssetString(override);
  const issuer = env.STELLAR_ASSET_ISSUER;
  if (!issuer || !StrKey.isValidEd25519PublicKey(issuer)) {
    throw new StellarConfigError(
      `No Stellar issuer configured for ${currency}. Set STELLAR_ASSET_ISSUER (run \`npm run stellar:bootstrap\`).`
    );
  }
  return new Asset(currency, issuer);
}

export function isStellarCurrency(value: string): value is StellarCurrency {
  return (STELLAR_CURRENCIES as readonly string[]).includes(value.toUpperCase());
}

/** Maps a Horizon balance line back to a FlowPay currency, or null for assets FlowPay doesn't manage. */
export function currencyForAsset(code: string, issuer: string): StellarCurrency | null {
  for (const currency of STELLAR_CURRENCIES) {
    try {
      const asset = assetFor(currency);
      if (asset.getCode() === code && asset.getIssuer() === issuer) return currency;
    } catch {
      // Unconfigured currency simply doesn't match.
    }
  }
  return null;
}

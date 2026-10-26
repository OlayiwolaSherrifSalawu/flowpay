import { Operation, StrKey, TransactionBuilder, type Horizon } from '@stellar/stellar-sdk';
import { InvalidRequestError, StellarError } from '../core/errors.js';
import { Money } from '../core/money.js';
import { fromStellarAmount } from './amount.js';
import {
  assetFor,
  currencyForAsset,
  explorerAccountUrl,
  getNetworkConfig,
  STELLAR_CURRENCIES,
  type StellarCurrency,
} from './config.js';
import { StellarHorizon } from './horizon.js';

export interface CurrencyBalance {
  currency: StellarCurrency;
  assetCode: string;
  assetIssuer: string;
  balance: Money;
  /** Raw 7-decimal Stellar string, for display of exact on-chain value. */
  rawBalance: string;
}

export interface AccountSummary {
  accountId: string;
  exists: boolean;
  xlmBalance: string;
  balances: CurrencyBalance[];
  /** FlowPay currencies this account cannot receive yet (no trustline). */
  missingTrustlines: StellarCurrency[];
  explorerUrl: string;
}

/** Transaction validity window for unsigned transactions handed to the device to sign. */
export const UNSIGNED_TX_TIMEOUT_SECONDS = 300;

export function assertAccountId(accountId: string): void {
  if (!StrKey.isValidEd25519PublicKey(accountId)) {
    throw new InvalidRequestError(`"${accountId}" is not a valid Stellar account ID (expected G...).`);
  }
}

export function summarizeAccount(accountId: string, account: Horizon.AccountResponse | null): AccountSummary {
  if (!account) {
    return {
      accountId,
      exists: false,
      xlmBalance: '0',
      balances: [],
      missingTrustlines: [...STELLAR_CURRENCIES],
      explorerUrl: explorerAccountUrl(accountId),
    };
  }

  let xlmBalance = '0';
  const balances: CurrencyBalance[] = [];
  for (const line of account.balances) {
    if (line.asset_type === 'native') {
      xlmBalance = line.balance;
      continue;
    }
    if (line.asset_type !== 'credit_alphanum4' && line.asset_type !== 'credit_alphanum12') continue;
    const currency = currencyForAsset(line.asset_code, line.asset_issuer);
    if (!currency) continue;
    balances.push({
      currency,
      assetCode: line.asset_code,
      assetIssuer: line.asset_issuer,
      balance: fromStellarAmount(line.balance, currency),
      rawBalance: line.balance,
    });
  }

  const held = new Set(balances.map((b) => b.currency));
  return {
    accountId,
    exists: true,
    xlmBalance,
    balances,
    missingTrustlines: STELLAR_CURRENCIES.filter((c) => !held.has(c)),
    explorerUrl: explorerAccountUrl(accountId),
  };
}

export class StellarAccountService {
  constructor(private readonly horizon: StellarHorizon = new StellarHorizon()) {}

  async getSummary(accountId: string): Promise<AccountSummary> {
    assertAccountId(accountId);
    const account = await this.horizon.findAccount(accountId);
    return summarizeAccount(accountId, account);
  }

  /**
   * Testnet only: asks Friendbot to create and fund the account with test XLM.
   * Throws on mainnet and on any Friendbot failure (except "already funded").
   */
  async fundWithFriendbot(accountId: string, fetchImpl: typeof fetch = fetch): Promise<{ funded: boolean; alreadyExisted: boolean }> {
    assertAccountId(accountId);
    const { friendbotUrl } = getNetworkConfig();
    if (!friendbotUrl) {
      throw new StellarError('Friendbot funding is only available on testnet.', 400, 'STELLAR_FRIENDBOT_UNAVAILABLE');
    }
    const res = await fetchImpl(`${friendbotUrl}?addr=${encodeURIComponent(accountId)}`);
    if (res.ok) return { funded: true, alreadyExisted: false };

    const body = (await res.json().catch(() => ({}))) as { detail?: string; extras?: any };
    const opCodes: string[] = body?.extras?.result_codes?.operations ?? [];
    if (opCodes.includes('op_already_exists') || /already funded/i.test(body?.detail ?? '')) {
      return { funded: false, alreadyExisted: true };
    }
    throw new StellarError(`Friendbot could not fund ${accountId}: ${body?.detail ?? res.statusText}`, 502, 'STELLAR_FRIENDBOT_FAILED');
  }

  /**
   * Builds an UNSIGNED transaction that adds trustlines for the requested currencies
   * (skipping ones the account already has). Returns null when nothing is needed.
   */
  async buildTrustlineTx(accountId: string, currencies: StellarCurrency[] = [...STELLAR_CURRENCIES]): Promise<{ xdr: string; currencies: StellarCurrency[] } | null> {
    assertAccountId(accountId);
    const account = await this.horizon.loadAccount(accountId);
    const summary = summarizeAccount(accountId, account);
    const needed = currencies.filter((c) => summary.missingTrustlines.includes(c));
    if (needed.length === 0) return null;

    const fee = await this.horizon.baseFee();
    const builder = new TransactionBuilder(account, { fee: String(fee), networkPassphrase: getNetworkConfig().passphrase });
    for (const currency of needed) {
      builder.addOperation(Operation.changeTrust({ asset: assetFor(currency) }));
    }
    const tx = builder.setTimeout(UNSIGNED_TX_TIMEOUT_SECONDS).build();
    return { xdr: tx.toXDR(), currencies: needed };
  }
}

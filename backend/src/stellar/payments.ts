import { Asset, Memo, Operation, TransactionBuilder } from '@stellar/stellar-sdk';
import { InvalidRequestError, StellarAccountNotFoundError, StellarError } from '../core/errors.js';
import { Money } from '../core/money.js';
import { summarizeAccount, type AccountSummary } from './accounts.js';
import { fromStellarAmountCeil, toStellarAmount, withSlippage } from './amount.js';
import { assetFor, getNetworkConfig, type StellarCurrency } from './config.js';
import { StellarHorizon, type PathQuote } from './horizon.js';
import type { ResolvedRecipient } from './directory.js';

/** Max extra the sender authorizes over the quoted conversion cost (path payments only). */
export const DEFAULT_SLIPPAGE_BPS = 100; // 1%
export const TRANSFER_TX_TIMEOUT_SECONDS = 300;

export interface FundingQuote {
  currency: StellarCurrency;
  available: Money;
  /** Quoted amount the sender pays (rounded up). Equals the destination amount for same-currency. */
  sourceAmount: Money;
  /** Hard cap signed into the transaction (sourceAmount + slippage for conversions). */
  sendMax: Money;
  path: Asset[];
  requiresConversion: boolean;
  /** Destination units received per 1 source unit, from the live quote. */
  rate: number;
  feasible: boolean;
}

function toAsset(a: { code: string; issuer: string | null }): Asset {
  return a.issuer ? new Asset(a.code, a.issuer) : Asset.native();
}

function bestQuote(quotes: PathQuote[]): PathQuote | null {
  if (quotes.length === 0) return null;
  return quotes.reduce((best, q) => (Number(q.sourceAmount) < Number(best.sourceAmount) ? q : best));
}

/**
 * Live funding options for paying `destAmount` of `destCurrency` from each currency the
 * sender actually holds. Conversion costs come from Horizon path-finding over real liquidity.
 */
export async function quoteFunding(
  horizon: StellarHorizon,
  summary: AccountSummary,
  destAmount: Money,
  slippageBps = DEFAULT_SLIPPAGE_BPS
): Promise<FundingQuote[]> {
  const destCurrency = destAmount.currency as StellarCurrency;
  const options: FundingQuote[] = [];

  for (const b of summary.balances) {
    if (!b.balance.isPositive()) continue;
    if (b.currency === destCurrency) {
      options.push({
        currency: b.currency,
        available: b.balance,
        sourceAmount: destAmount,
        sendMax: destAmount,
        path: [],
        requiresConversion: false,
        rate: 1,
        feasible: !destAmount.isGreaterThan(b.balance),
      });
      continue;
    }
    const quote = bestQuote(await horizon.quoteStrictReceive([assetFor(b.currency)], assetFor(destCurrency), toStellarAmount(destAmount)));
    if (!quote) continue; // no liquidity path for this pair right now
    const sourceAmount = fromStellarAmountCeil(quote.sourceAmount, b.currency);
    const sendMax = withSlippage(sourceAmount, slippageBps);
    options.push({
      currency: b.currency,
      available: b.balance,
      sourceAmount,
      sendMax,
      path: quote.path.map(toAsset),
      requiresConversion: true,
      rate: Number(destAmount.toMajorString()) / Number(sourceAmount.toMajorString()),
      feasible: !sendMax.isGreaterThan(b.balance),
    });
  }

  // Direct first, then cheapest-relative-to-balance conversions.
  return options.sort((a, b) => Number(a.requiresConversion) - Number(b.requiresConversion));
}

/** Fails with a clear message if the destination cannot receive `currency`. */
export async function assertCanReceive(horizon: StellarHorizon, recipient: ResolvedRecipient, currency: StellarCurrency): Promise<void> {
  let summary: AccountSummary;
  try {
    summary = summarizeAccount(recipient.accountId, await horizon.loadAccount(recipient.accountId));
  } catch (err) {
    if (err instanceof StellarAccountNotFoundError) {
      throw new InvalidRequestError(`${recipient.displayName}'s wallet is not active on Stellar yet.`);
    }
    throw err;
  }
  if (summary.missingTrustlines.includes(currency)) {
    throw new InvalidRequestError(`${recipient.displayName} has not enabled ${currency} in their wallet yet.`);
  }
}

function memoFor(recipient: ResolvedRecipient, purpose?: string) {
  if (recipient.memo) return recipient.memo.type === 'id' ? Memo.id(recipient.memo.value) : Memo.text(recipient.memo.value);
  if (!purpose) return Memo.none();
  // Memo.text is limited to 28 BYTES.
  let text = purpose.trim();
  while (Buffer.byteLength(text, 'utf8') > 28) text = text.slice(0, -1);
  return text ? Memo.text(text) : Memo.none();
}

export interface BuiltTransfer {
  xdr: string;
  hash: string;
  expiresAt: string;
}

/**
 * Builds an UNSIGNED payment (same currency) or path payment (conversion) from the
 * sender's account. The sender's device signs it; nothing here can move funds.
 */
export async function buildTransferTx(args: {
  horizon: StellarHorizon;
  sourceAccountId: string;
  recipient: ResolvedRecipient;
  destAmount: Money;
  funding: FundingQuote;
  purpose?: string;
}): Promise<BuiltTransfer> {
  const { horizon, sourceAccountId, recipient, destAmount, funding } = args;
  if (recipient.accountId === sourceAccountId && !funding.requiresConversion) {
    throw new InvalidRequestError('You cannot send money to your own wallet in the same currency.');
  }
  const account = await horizon.loadAccount(sourceAccountId);
  const fee = await horizon.baseFee();
  const destAsset = assetFor(destAmount.currency as StellarCurrency);

  const op = funding.requiresConversion
    ? Operation.pathPaymentStrictReceive({
        sendAsset: assetFor(funding.currency),
        sendMax: toStellarAmount(funding.sendMax),
        destination: recipient.accountId,
        destAsset,
        destAmount: toStellarAmount(destAmount),
        path: funding.path,
      })
    : Operation.payment({ destination: recipient.accountId, asset: destAsset, amount: toStellarAmount(destAmount) });

  const tx = new TransactionBuilder(account, { fee: String(fee), networkPassphrase: getNetworkConfig().passphrase })
    .addOperation(op)
    .addMemo(memoFor(recipient, args.purpose))
    .setTimeout(TRANSFER_TX_TIMEOUT_SECONDS)
    .build();

  const maxTime = Number(tx.timeBounds?.maxTime ?? 0);
  if (!maxTime) throw new StellarError('Transaction is missing an expiry.', 500, 'STELLAR_BUILD_FAILED');
  return { xdr: tx.toXDR(), hash: Buffer.from(tx.hash()).toString('hex'), expiresAt: new Date(maxTime * 1000).toISOString() };
}

import { Asset, Claimant, Memo, Operation, TransactionBuilder, type xdr } from '@stellar/stellar-sdk';
import { InsufficientFundsError, InvalidRequestError } from '../core/errors.js';
import { Money } from '../core/money.js';
import { summarizeAccount } from './accounts.js';
import { fromStellarAmount, fromStellarAmountCeil, toStellarAmount, withSlippage } from './amount.js';
import { assetFor, getNetworkConfig, isStellarCurrency, type StellarCurrency } from './config.js';
import { resolveRecipient, type ResolvedRecipient } from './directory.js';
import { StellarHorizon, type PathQuote } from './horizon.js';
import { assertCanReceive, DEFAULT_SLIPPAGE_BPS, TRANSFER_TX_TIMEOUT_SECONDS } from './payments.js';

/**
 * One atomic Stellar transaction carrying several money movements ("legs").
 * Used by the AI operator, money missions and payroll. All legs settle together or none do.
 *
 *  - to: 'self'        → conversion between your own currencies (path payment to yourself)
 *  - to: <recipient>   → payment (same currency) or path payment (conversion)
 *  - lockUntil         → the received funds go into a claimable balance that only YOU can
 *                        claim, and only after that time (Stellar-native locked savings)
 *  - mode exact_receive → `amount` is what the destination gets (cost quoted, capped by sendMax)
 *  - mode exact_send    → `amount` is what you spend (receipt quoted, floored by destMin)
 */
export const MAX_OPS_PER_TX = 100;

export interface BatchLegInput {
  label: string;
  to: 'self' | string;
  mode: 'exact_receive' | 'exact_send';
  amount: { amountMinor: string; currency: string };
  /** Currency received; defaults to amount.currency (exact_receive) or fundingCurrency. */
  destCurrency?: string;
  /** Currency spent; defaults to amount.currency (exact_send) or destCurrency. */
  fundingCurrency?: string;
  lockUntil?: string;
}

export interface BatchLegQuote {
  index: number;
  label: string;
  recipient: { accountId: string; displayName: string; userId?: string; self: boolean };
  fundingCurrency: StellarCurrency;
  destCurrency: StellarCurrency;
  /** Expected spend and the hard cap signed into the tx (equal for same-currency legs). */
  sourceAmount: Money;
  maxSourceAmount: Money;
  /** Expected receipt and the floor signed into the tx (equal for same-currency legs). */
  destAmount: Money;
  minDestAmount: Money;
  requiresConversion: boolean;
  lockUntil?: string;
  operationCount: number;
}

export interface BuiltBatch {
  xdr: string;
  hash: string;
  expiresAt: string;
  legs: BatchLegQuote[];
  /** Worst-case spend per funding currency, as signed. */
  maxTotals: Record<string, string>;
}

function cur(code: string | undefined, field: string): StellarCurrency {
  const upper = (code ?? '').toUpperCase();
  if (!isStellarCurrency(upper)) throw new InvalidRequestError(`${field} "${code}" is not a supported currency.`);
  return upper as StellarCurrency;
}

function toAsset(a: { code: string; issuer: string | null }): Asset {
  return a.issuer ? new Asset(a.code, a.issuer) : Asset.native();
}

function cheapest(quotes: PathQuote[]): PathQuote | null {
  return quotes.reduce<PathQuote | null>((b, q) => (!b || Number(q.sourceAmount) < Number(b.sourceAmount) ? q : b), null);
}

function richest(quotes: PathQuote[]): PathQuote | null {
  return quotes.reduce<PathQuote | null>((b, q) => (!b || Number(q.destinationAmount) > Number(b.destinationAmount) ? q : b), null);
}

function floorBps(m: Money, bps: number): Money {
  return m.subtract(m.multiplyBasisPoints(bps));
}

export async function buildBatch(args: {
  horizon: StellarHorizon;
  sourceAccountId: string;
  legs: BatchLegInput[];
  memo?: string;
  slippageBps?: number;
}): Promise<BuiltBatch> {
  const { horizon, sourceAccountId } = args;
  const slippage = args.slippageBps ?? DEFAULT_SLIPPAGE_BPS;
  if (!Array.isArray(args.legs) || args.legs.length === 0) throw new InvalidRequestError('At least one payment is required.');

  const account = await horizon.loadAccount(sourceAccountId);
  const summary = summarizeAccount(sourceAccountId, account);
  const recipients = new Map<string, ResolvedRecipient>();
  const ops: xdr.Operation[] = [];
  const quotes: BatchLegQuote[] = [];
  const maxSpend = new Map<StellarCurrency, Money>();

  for (const [index, leg] of args.legs.entries()) {
    const amountCurrency = cur(leg.amount?.currency, `legs[${index}].amount.currency`);
    const amount = Money.fromMinor(leg.amount.amountMinor, amountCurrency);
    if (!amount.isPositive()) throw new InvalidRequestError(`${leg.label}: amount must be greater than zero.`);

    const destCurrency = cur(leg.destCurrency ?? (leg.mode === 'exact_receive' ? amountCurrency : leg.fundingCurrency ?? amountCurrency), `${leg.label} destination currency`);
    const fundingCurrency = cur(leg.fundingCurrency ?? (leg.mode === 'exact_send' ? amountCurrency : destCurrency), `${leg.label} funding currency`);
    if (leg.mode === 'exact_receive' && amountCurrency !== destCurrency) throw new InvalidRequestError(`${leg.label}: exact_receive amount must be in the destination currency.`);
    if (leg.mode === 'exact_send' && amountCurrency !== fundingCurrency) throw new InvalidRequestError(`${leg.label}: exact_send amount must be in the funding currency.`);

    const self = leg.to === 'self';
    let recipient: ResolvedRecipient;
    if (self) {
      recipient = { accountId: sourceAccountId, displayName: 'You', source: 'account_id' };
    } else {
      recipient = recipients.get(leg.to) ?? (await resolveRecipient(leg.to));
      recipients.set(leg.to, recipient);
      if (recipient.accountId === sourceAccountId) throw new InvalidRequestError(`${leg.label}: use "self" to move money between your own currencies.`);
      if (!leg.lockUntil) await assertCanReceive(horizon, recipient, destCurrency);
    }
    if (self && fundingCurrency === destCurrency && !leg.lockUntil) {
      throw new InvalidRequestError(`${leg.label}: converting ${fundingCurrency} to ${fundingCurrency} does nothing.`);
    }
    if (leg.lockUntil && !self) throw new InvalidRequestError(`${leg.label}: only your own savings can be locked.`);

    const conversion = fundingCurrency !== destCurrency;
    let sourceAmount: Money, maxSourceAmount: Money, destAmount: Money, minDestAmount: Money, path: Asset[] = [];

    if (!conversion) {
      sourceAmount = maxSourceAmount = destAmount = minDestAmount = Money.fromMinor(amount.amountMinor, destCurrency);
    } else if (leg.mode === 'exact_receive') {
      const q = cheapest(await horizon.quoteStrictReceive([assetFor(fundingCurrency)], assetFor(destCurrency), toStellarAmount(amount)));
      if (!q) throw new InvalidRequestError(`${leg.label}: no ${fundingCurrency}→${destCurrency} liquidity right now.`);
      destAmount = minDestAmount = amount;
      sourceAmount = fromStellarAmountCeil(q.sourceAmount, fundingCurrency);
      maxSourceAmount = withSlippage(sourceAmount, slippage);
      path = q.path.map(toAsset);
    } else {
      const q = richest(await horizon.quoteStrictSend(assetFor(fundingCurrency), toStellarAmount(amount), [assetFor(destCurrency)]));
      if (!q) throw new InvalidRequestError(`${leg.label}: no ${fundingCurrency}→${destCurrency} liquidity right now.`);
      sourceAmount = maxSourceAmount = amount;
      destAmount = fromStellarAmount(q.destinationAmount, destCurrency);
      minDestAmount = floorBps(destAmount, slippage);
      path = q.path.map(toAsset);
    }

    // When locking converted funds, the converted funds land on our own account first.
    const payTo = leg.lockUntil ? sourceAccountId : recipient.accountId;
    let opCount = 0;
    if (conversion) {
      ops.push(
        leg.mode === 'exact_receive'
          ? Operation.pathPaymentStrictReceive({ sendAsset: assetFor(fundingCurrency), sendMax: toStellarAmount(maxSourceAmount), destination: payTo, destAsset: assetFor(destCurrency), destAmount: toStellarAmount(destAmount), path })
          : Operation.pathPaymentStrictSend({ sendAsset: assetFor(fundingCurrency), sendAmount: toStellarAmount(sourceAmount), destination: payTo, destAsset: assetFor(destCurrency), destMin: toStellarAmount(minDestAmount), path })
      );
      opCount++;
    } else if (!self) {
      ops.push(Operation.payment({ destination: recipient.accountId, asset: assetFor(destCurrency), amount: toStellarAmount(destAmount) }));
      opCount++;
    }
    if (leg.lockUntil) {
      const unlock = Date.parse(leg.lockUntil);
      if (!Number.isFinite(unlock) || unlock <= Date.now()) throw new InvalidRequestError(`${leg.label}: lock date must be in the future.`);
      const unixSeconds = String(Math.floor(unlock / 1000));
      ops.push(
        Operation.createClaimableBalance({
          asset: assetFor(destCurrency),
          amount: toStellarAmount(minDestAmount),
          claimants: [new Claimant(sourceAccountId, Claimant.predicateNot(Claimant.predicateBeforeAbsoluteTime(unixSeconds)))],
        })
      );
      opCount++;
    }

    maxSpend.set(fundingCurrency, (maxSpend.get(fundingCurrency) ?? Money.zero(fundingCurrency)).add(maxSourceAmount));
    quotes.push({
      index,
      label: leg.label,
      recipient: { accountId: recipient.accountId, displayName: recipient.displayName, userId: recipient.userId, self },
      fundingCurrency,
      destCurrency,
      sourceAmount,
      maxSourceAmount,
      destAmount,
      minDestAmount,
      requiresConversion: conversion,
      lockUntil: leg.lockUntil,
      operationCount: opCount,
    });
  }

  if (ops.length > MAX_OPS_PER_TX) {
    throw new InvalidRequestError(`This batch needs ${ops.length} operations; Stellar allows ${MAX_OPS_PER_TX} per transaction.`);
  }
  for (const [currency, needed] of maxSpend) {
    const held = summary.balances.find((b) => b.currency === currency)?.balance ?? Money.zero(currency);
    if (needed.isGreaterThan(held)) {
      throw new InsufficientFundsError(`You need up to ${needed.toMajorString()} ${currency} but hold ${held.toMajorString()} ${currency}.`);
    }
  }

  const fee = await horizon.baseFee();
  const builder = new TransactionBuilder(account, { fee: String(fee), networkPassphrase: getNetworkConfig().passphrase });
  ops.forEach((op) => builder.addOperation(op));
  if (args.memo) {
    let text = args.memo.trim();
    while (Buffer.byteLength(text, 'utf8') > 28) text = text.slice(0, -1);
    if (text) builder.addMemo(Memo.text(text));
  }
  const tx = builder.setTimeout(TRANSFER_TX_TIMEOUT_SECONDS).build();
  return {
    xdr: tx.toXDR(),
    hash: Buffer.from(tx.hash()).toString('hex'),
    expiresAt: new Date(Number(tx.timeBounds!.maxTime) * 1000).toISOString(),
    legs: quotes,
    maxTotals: Object.fromEntries([...maxSpend].map(([c, m]) => [c, m.toMajorString()])),
  };
}

export function serializeLeg(q: BatchLegQuote) {
  return {
    ...q,
    sourceAmount: q.sourceAmount.toMajorString(),
    maxSourceAmount: q.maxSourceAmount.toMajorString(),
    destAmount: q.destAmount.toMajorString(),
    minDestAmount: q.minDestAmount.toMajorString(),
    sourceAmountMinor: q.sourceAmount.amountMinor.toString(),
    destAmountMinor: q.destAmount.amountMinor.toString(),
  };
}

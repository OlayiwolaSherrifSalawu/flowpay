import { Money, type SupportedCurrency } from '../core/money.js';

/**
 * Stellar amounts are decimal strings with up to 7 fractional digits ("12.3400000").
 * FlowPay stores integer minor units with 2 decimals. These helpers convert without floats.
 */

const STELLAR_DECIMALS = 7;

/** Money → Stellar amount string ("1050" cents → "10.50"). */
export function toStellarAmount(money: Money): string {
  if (money.amountMinor <= 0n) {
    throw new RangeError(`Stellar amounts must be positive, got ${money.toMajorString()} ${money.currency}`);
  }
  return money.toMajorString();
}

/**
 * Stellar amount string → Money, rounding toward zero to 2 decimals. Used for balances,
 * where showing slightly less than the on-chain dust is the safe direction.
 */
export function fromStellarAmount(amount: string, currency: SupportedCurrency): Money {
  return Money.fromMajor(amount, currency);
}

/**
 * Stellar amount string → Money, rounding UP to 2 decimals. Used for quoted costs
 * (e.g. path-payment source amounts) so we never under-quote what the user will pay.
 */
export function fromStellarAmountCeil(amount: string, currency: SupportedCurrency): Money {
  const [whole, frac = ''] = amount.trim().split('.');
  const padded = frac.padEnd(STELLAR_DECIMALS, '0');
  const truncated = Money.fromMajor(`${whole}.${padded.slice(0, 2)}`, currency);
  const hasRemainder = /[1-9]/.test(padded.slice(2));
  return hasRemainder ? truncated.add(Money.fromMinor(1n, currency)) : truncated;
}

/** Applies a slippage cap in basis points to a quoted source amount (e.g. 100 bps = +1%). */
export function withSlippage(money: Money, bps: number): Money {
  const bump = money.multiplyBasisPoints(bps);
  return money.add(bump.isZero() ? Money.fromMinor(1n, money.currency) : bump);
}

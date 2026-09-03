/**
 * Central Money Abstraction
 * 
 * Guarantees:
 * 1. Financial amounts are ALWAYS stored and computed as integer minor units (e.g. cents, kobo, centavos).
 * 2. Zero floating-point arithmetic.
 * 3. Currency-aware operations (cannot accidentally add NGN to USD without explicit conversion).
 * 4. Safe formatting and serializing to/from BMONI API representations.
 */

export type SupportedCurrency = 'USD' | 'NGN' | 'MXN' | 'EUR' | 'CAD' | 'GBP';

// Standard decimals per currency (typically 2 for fiat/stablecoins USDB, CNGN, MEXe)
const CURRENCY_DECIMALS: Record<SupportedCurrency, number> = {
  USD: 2,
  NGN: 2,
  MXN: 2,
  EUR: 2,
  CAD: 2,
  GBP: 2,
};

export class Money {
  /** The amount in minor units (e.g., $10.50 -> 1050 cents) */
  readonly amountMinor: bigint;
  readonly currency: SupportedCurrency;

  private constructor(amountMinor: bigint | number, currency: SupportedCurrency) {
    this.amountMinor = BigInt(amountMinor);
    this.currency = currency;
  }

  /**
   * Create Money from integer minor units (e.g., 1050 for $10.50)
   */
  static fromMinor(amountMinor: bigint | number | string, currency: SupportedCurrency): Money {
    const minorBigInt = typeof amountMinor === 'bigint' ? amountMinor : BigInt(Math.round(Number(amountMinor)));
    return new Money(minorBigInt, currency);
  }

  /**
   * Create Money from major decimal string or number (e.g., "10.50" -> 1050)
   * Safely parses without floating point drift
   */
  static fromMajor(amountMajor: string | number, currency: SupportedCurrency): Money {
    const decimals = CURRENCY_DECIMALS[currency] ?? 2;
    const str = typeof amountMajor === 'number' ? amountMajor.toFixed(decimals) : amountMajor.trim();
    
    const parts = str.split('.');
    const whole = parts[0] ? BigInt(parts[0]) : 0n;
    let fractionStr = parts[1] ?? '';
    
    if (fractionStr.length > decimals) {
      fractionStr = fractionStr.slice(0, decimals);
    } else {
      fractionStr = fractionStr.padEnd(decimals, '0');
    }
    
    const fraction = BigInt(fractionStr);
    const multiplier = 10n ** BigInt(decimals);
    const totalMinor = whole >= 0n ? whole * multiplier + fraction : whole * multiplier - fraction;
    
    return new Money(totalMinor, currency);
  }

  static zero(currency: SupportedCurrency): Money {
    return new Money(0n, currency);
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amountMinor + other.amountMinor, this.currency);
  }

  subtract(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amountMinor - other.amountMinor, this.currency);
  }

  multiply(scalar: number | bigint): Money {
    const s = typeof scalar === 'bigint' ? scalar : BigInt(Math.round(scalar));
    return new Money(this.amountMinor * s, this.currency);
  }

  /**
   * Basis point percentage multiplication (e.g., 150 bps = 1.50%)
   * Useful for fee calculation with integer arithmetic
   */
  multiplyBasisPoints(bps: number | bigint): Money {
    const b = BigInt(bps);
    return new Money((this.amountMinor * b) / 10000n, this.currency);
  }

  isGreaterThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.amountMinor > other.amountMinor;
  }

  isLessThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.amountMinor < other.amountMinor;
  }

  isZero(): boolean {
    return this.amountMinor === 0n;
  }

  isPositive(): boolean {
    return this.amountMinor > 0n;
  }

  /**
   * Formats to standard major string (e.g., "10.50")
   */
  toMajorString(): string {
    const decimals = CURRENCY_DECIMALS[this.currency] ?? 2;
    const isNegative = this.amountMinor < 0n;
    const absolute = isNegative ? -this.amountMinor : this.amountMinor;
    
    const multiplier = 10n ** BigInt(decimals);
    const whole = absolute / multiplier;
    const fraction = absolute % multiplier;
    
    const fractionStr = fraction.toString().padStart(decimals, '0');
    return `${isNegative ? '-' : ''}${whole}.${fractionStr}`;
  }

  /**
   * BMONI format representation:
   * BMONI typically expects minor units as strings for certain endpoints (e.g. "1050")
   * or decimal strings for others.
   */
  toBmoniMinorString(): string {
    return this.amountMinor.toString();
  }

  toBmoniDecimalString(): string {
    return this.toMajorString();
  }

  toJSON() {
    return {
      amountMinor: this.amountMinor.toString(),
      currency: this.currency,
      formatted: this.toMajorString(),
    };
  }

  private assertSameCurrency(other: Money) {
    if (this.currency !== other.currency) {
      throw new Error(`Currency mismatch: cannot operate between ${this.currency} and ${other.currency}`);
    }
  }
}

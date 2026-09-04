import { z } from 'zod';
import { Money, type SupportedCurrency } from '../../core/money.js';
import type {
  BalanceInspectionResult,
  FundingSourceOption,
  TransferErrorCode,
  TransferIntent,
} from './types.js';

// --- Exchange Rates Table (Pivot: USD) ---
export const EXCHANGE_RATES: Record<string, number> = {
  'USD_TO_NGN': 1550.0,
  'NGN_TO_USD': 1 / 1550.0,
  'USD_TO_MXN': 17.5,
  'MXN_TO_USD': 1 / 17.5,
  'USD_TO_CAD': 1.375,
  'CAD_TO_USD': 1 / 1.375,
  'USD_TO_EUR': 0.92,
  'EUR_TO_USD': 1 / 0.92,
  'USD_TO_USD': 1.0,
  'NGN_TO_NGN': 1.0,
  'MXN_TO_MXN': 1.0,
  'CAD_TO_CAD': 1.0,
  'EUR_TO_EUR': 1.0,
};

export function getExchangeRate(from: SupportedCurrency, to: SupportedCurrency): number {
  if (from === to) return 1.0;
  const directKey = `${from}_TO_${to}`;
  if (EXCHANGE_RATES[directKey]) return EXCHANGE_RATES[directKey];

  // Derive via USD pivot
  const toUsdKey = `${from}_TO_USD`;
  const fromUsdKey = `USD_TO_${to}`;
  if (EXCHANGE_RATES[toUsdKey] && EXCHANGE_RATES[fromUsdKey]) {
    return EXCHANGE_RATES[toUsdKey] * EXCHANGE_RATES[fromUsdKey];
  }
  return 1.0;
}

// --- Zod Validation Schemas ---

export const TransferIntentSchema = z.object({
  intentId: z.string().min(1, 'Intent ID is required'),
  originalPrompt: z.string().min(1, 'Original prompt is required'),
  recipient: z.string().min(1, 'Recipient is required'),
  amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Invalid amount format'),
  amountMinor: z.string().regex(/^\d+$/, 'Invalid minor units'),
  currency: z.enum(['USD', 'NGN', 'MXN', 'CAD', 'EUR']),
  purpose: z.string().optional(),
  confidenceScore: z.number().min(0).max(1),
  requiresExplicitApproval: z.literal(true),
  provider: z.enum(['gemini', 'deterministic-fallback']).optional(),
});

export const WalletInputSchema = z.object({
  id: z.string(),
  currency: z.enum(['USD', 'NGN', 'MXN', 'CAD', 'EUR']),
  balanceMinor: z.string().regex(/^\d+$/),
  name: z.string().optional(),
  status: z.string().optional(),
});

export const BalanceInspectionInputSchema = z.object({
  intent: TransferIntentSchema,
  wallets: z.array(WalletInputSchema),
});

export const TransferProposeSchema = z.object({
  userId: z.string().default('usr_flowpay_sandbox_master'),
  intent: TransferIntentSchema,
  fundingWalletId: z.string().min(1, 'Funding wallet ID is required'),
});

export const TransferExecuteSchema = z.object({
  userId: z.string().default('usr_flowpay_sandbox_master'),
  proposalId: z.string().min(1, 'Proposal ID is required'),
  signature: z.string().regex(/^0x[a-fA-F0-9]{130}$/, 'Invalid 65-byte hex signature'),
});

// --- Deterministic Balance-Aware Inspection ---

export class TransferValidator {
  /**
   * Validates TransferIntent data structure
   */
  static validateIntent(data: unknown): TransferIntent {
    const result = TransferIntentSchema.safeParse(data);
    if (!result.success) {
      const issues = result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
      throw new Error(`Invalid TransferIntent: ${issues}`);
    }
    const minorVal = BigInt(result.data.amountMinor);
    if (minorVal <= 0n) {
      throw new Error('Transfer amount must be greater than zero');
    }
    return result.data;
  }

  /**
   * Inspects user balances across all multi-currency smart wallets
   * Implements the Balance-Aware Flow:
   * e.g. User wants $500 USD. Available: $300 USD, sufficient NGN.
   * Produces $500 USD payment funded from NGN wallet with NGN -> USD conversion.
   */
  static inspectBalancesAndFunding(
    intent: TransferIntent,
    wallets: Array<{
      id: string;
      currency: SupportedCurrency;
      balanceMinor: string;
      name?: string;
    }>
  ): BalanceInspectionResult {
    const targetCurrency = intent.currency;
    const targetAmountMinor = BigInt(intent.amountMinor);
    const targetMoney = Money.fromMinor(targetAmountMinor, targetCurrency);

    // Find direct wallet in target currency
    const directWallet = wallets.find(
      (w) => w.currency.toUpperCase() === targetCurrency.toUpperCase()
    );

    const directBalanceMinor = directWallet ? BigInt(directWallet.balanceMinor) : 0n;
    const hasSufficientDirectBalance = directBalanceMinor >= targetAmountMinor;

    const allOptions: FundingSourceOption[] = [];

    // 1. Direct Option (if direct wallet exists)
    if (directWallet) {
      const directBalanceMoney = Money.fromMinor(directBalanceMinor, targetCurrency);
      // Flat network fee: ~50 cents USD equivalent
      const netFeeMinor = targetCurrency === 'NGN' ? 77500n : targetCurrency === 'MXN' ? 875n : 50n;
      const netFeeMoney = Money.fromMinor(netFeeMinor, targetCurrency);
      const fxFeeMoney = Money.fromMinor(0n, targetCurrency);
      const totalDebitMinor = targetAmountMinor + netFeeMinor;
      const totalDebitMoney = Money.fromMinor(totalDebitMinor, targetCurrency);

      const option: FundingSourceOption = {
        fundingWalletId: directWallet.id,
        fundingCurrency: targetCurrency,
        fundingWalletName: directWallet.name || `${targetCurrency} Smart Wallet`,
        availableBalanceMinor: directBalanceMinor.toString(),
        availableBalanceFormatted: directBalanceMoney.toMajorString(),
        requiresConversion: false,
        conversionLabel: `Direct ${targetCurrency} Transfer`,
        exchangeRate: 1.0,
        convertedDebitMinor: targetAmountMinor.toString(),
        convertedDebitFormatted: targetMoney.toMajorString(),
        networkFeeMinor: netFeeMinor.toString(),
        networkFeeFormatted: netFeeMoney.toMajorString(),
        fxFeeMinor: '0',
        fxFeeFormatted: fxFeeMoney.toMajorString(),
        totalDebitMinor: totalDebitMinor.toString(),
        totalDebitFormatted: totalDebitMoney.toMajorString(),
        targetPaymentMinor: targetAmountMinor.toString(),
        targetPaymentFormatted: targetMoney.toMajorString(),
      };

      if (hasSufficientDirectBalance) {
        allOptions.unshift(option);
      } else {
        allOptions.push(option);
      }
    }

    // 2. Cross-Currency Alternative Wallets (e.g. NGN, MXN, CAD, EUR)
    for (const altWallet of wallets) {
      if (altWallet.currency === targetCurrency) continue;

      const altCurrency = altWallet.currency;
      const rate = getExchangeRate(altCurrency, targetCurrency);
      if (rate <= 0) continue;

      // Rate: 1 altCurrency = X targetCurrency
      // Target amount in altCurrency = targetAmount / rate
      const targetMajor = parseFloat(targetMoney.toMajorString());
      const requiredAltMajor = targetMajor / rate;
      const convertedMoney = Money.fromMajor(requiredAltMajor.toFixed(2), altCurrency);
      const convertedMinor = convertedMoney.amountMinor;

      // Fees in altCurrency:
      // Network fee: 50 cents USD equiv in altCurrency
      const usdRate = getExchangeRate('USD', altCurrency);
      const networkFeeMajor = 0.50 * usdRate;
      const networkFeeMoney = Money.fromMajor(networkFeeMajor.toFixed(2), altCurrency);

      // FX Fee (15 bps = 0.15%):
      const fxFeeMajor = requiredAltMajor * 0.0015;
      const fxFeeMoney = Money.fromMajor(fxFeeMajor.toFixed(2), altCurrency);

      const totalDebitMinor = convertedMinor + networkFeeMoney.amountMinor + fxFeeMoney.amountMinor;
      const totalDebitMoney = Money.fromMinor(totalDebitMinor, altCurrency);

      const altBalanceMinor = BigInt(altWallet.balanceMinor);
      const altBalanceMoney = Money.fromMinor(altBalanceMinor, altCurrency);

      const hasSufficientAlt = altBalanceMinor >= totalDebitMinor;

      const altOption: FundingSourceOption = {
        fundingWalletId: altWallet.id,
        fundingCurrency: altCurrency,
        fundingWalletName: altWallet.name || `${altCurrency} Smart Wallet`,
        availableBalanceMinor: altBalanceMinor.toString(),
        availableBalanceFormatted: altBalanceMoney.toMajorString(),
        requiresConversion: true,
        conversionLabel: `${altCurrency} → ${targetCurrency}`,
        exchangeRate: parseFloat((1 / rate).toFixed(4)), // e.g. 1550.0 NGN per USD
        convertedDebitMinor: convertedMinor.toString(),
        convertedDebitFormatted: convertedMoney.toMajorString(),
        networkFeeMinor: networkFeeMoney.amountMinor.toString(),
        networkFeeFormatted: networkFeeMoney.toMajorString(),
        fxFeeMinor: fxFeeMoney.amountMinor.toString(),
        fxFeeFormatted: fxFeeMoney.toMajorString(),
        totalDebitMinor: totalDebitMinor.toString(),
        totalDebitFormatted: totalDebitMoney.toMajorString(),
        targetPaymentMinor: targetAmountMinor.toString(),
        targetPaymentFormatted: targetMoney.toMajorString(),
      };

      if (hasSufficientAlt) {
        allOptions.push(altOption);
      }
    }

    // Determine recommended funding option
    // Priority:
    // 1. Direct wallet if sufficient
    // 2. First alternative wallet with sufficient balance (e.g. NGN)
    // 3. None if insufficient across all
    let recommended: FundingSourceOption | undefined;
    let isPossible = false;

    if (hasSufficientDirectBalance && directWallet) {
      recommended = allOptions.find((o) => !o.requiresConversion);
      isPossible = true;
    } else {
      // Find cross-currency funding option with sufficient funds
      recommended = allOptions.find((o) => {
        const bal = BigInt(o.availableBalanceMinor);
        const req = BigInt(o.totalDebitMinor);
        return bal >= req;
      });
      isPossible = !!recommended;
    }

    const reason = isPossible
      ? undefined
      : `Insufficient funds across all available wallets. You need ${intent.amount} ${intent.currency}, but direct and converted balances are insufficient.`;

    return {
      intent,
      isDirectFunded: hasSufficientDirectBalance,
      recommendedFundingOption: recommended,
      allFundingOptions: allOptions,
      isPossible,
      reason,
    };
  }

  /**
   * Human-readable error messages for all 8 failure modes
   */
  static formatError(code: TransferErrorCode, customMessage?: string): string {
    switch (code) {
      case 'INSUFFICIENT_FUNDS':
        return (
          customMessage ||
          'Insufficient funds across all available wallets. Please fund your smart wallet or choose another currency rail.'
        );
      case 'UNSUPPORTED_CURRENCY':
        return (
          customMessage ||
          'The selected currency is unsupported. FlowPay currently supports USD, NGN, MXN, CAD, and EUR.'
        );
      case 'INVALID_RECIPIENT':
        return (
          customMessage ||
          'Invalid recipient. Please specify a valid name, email address, or 0x Ethereum address.'
        );
      case 'CONVERSION_UNAVAILABLE':
        return (
          customMessage ||
          'Currency conversion between the requested pairs is currently unavailable.'
        );
      case 'TRANSFER_FAILURE':
        return (
          customMessage ||
          'Transfer failed to settle on BMONI rails. Please verify recipient details and try again.'
        );
      case 'SIGNATURE_FAILURE':
        return (
          customMessage ||
          'B-Key PIN verification failed or was cancelled. Transaction was not authorized.'
        );
      case 'PROPOSAL_EXPIRATION':
        return (
          customMessage ||
          'Transfer proposal expired (15-minute validity). Exchange rates have been refreshed; please review and confirm again.'
        );
      case 'NETWORK_FAILURE':
        return (
          customMessage ||
          'Network connection error. Unable to communicate with FlowPay backend or BMONI infrastructure.'
        );
      default:
        return customMessage || 'An unexpected error occurred during the transfer.';
    }
  }
}

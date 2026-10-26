import { z } from 'zod';
import { Money, type SupportedCurrency } from '../../core/money.js';
import type {
  BalanceInspectionResult,
  FundingSourceOption,
  TransferErrorCode,
  TransferIntent,
} from './types.js';

// --- Zod Validation Schemas ---

export const TransferIntentSchema = z.object({
  intentId: z.string().min(1, 'Intent ID is required'),
  originalPrompt: z.string().optional().default('Direct Transfer').transform(v => (v && v.trim().length > 0) ? v : 'Direct Transfer'),
  recipient: z.string().min(1, 'Recipient is required'),
  amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Invalid amount format'),
  amountMinor: z.string().regex(/^\d+$/, 'Invalid minor units'),
  currency: z.enum(['USD', 'NGN', 'MXN', 'CAD', 'GBP']),
  purpose: z.string().optional(),
  confidenceScore: z.number().min(0).max(1),
  requiresExplicitApproval: z.literal(true),
  provider: z.enum(['gemini', 'deterministic-fallback']).optional(),
});

export const WalletInputSchema = z.object({
  id: z.string(),
  currency: z.enum(['USD', 'NGN', 'MXN', 'CAD', 'GBP']),
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
  signature: z.string().regex(/^0x[a-fA-F0-9]{64,130}$/, 'Invalid signature format'),
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
          'Transfer failed to settle on Stellar. Please verify recipient details and try again.'
        );
      case 'SIGNATURE_FAILURE':
        return (
          customMessage ||
          'PIN verification failed or was cancelled. Transaction was not authorized.'
        );
      case 'PROPOSAL_EXPIRATION':
        return (
          customMessage ||
          'Transfer proposal expired (15-minute validity). Exchange rates have been refreshed; please review and confirm again.'
        );
      case 'NETWORK_FAILURE':
        return (
          customMessage ||
          'Network connection error. Unable to communicate with FlowPay or the Stellar network infrastructure.'
        );
      default:
        return customMessage || 'An unexpected error occurred during the transfer.';
    }
  }
}

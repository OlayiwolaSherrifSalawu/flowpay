import type { SupportedCurrency } from '../../core/money.js';

export type TransferErrorCode =
  | 'INSUFFICIENT_FUNDS'
  | 'UNSUPPORTED_CURRENCY'
  | 'INVALID_RECIPIENT'
  | 'CONVERSION_UNAVAILABLE'
  | 'TRANSFER_FAILURE'
  | 'SIGNATURE_FAILURE'
  | 'PROPOSAL_EXPIRATION'
  | 'NETWORK_FAILURE';

export interface TransferIntent {
  intentId: string;
  originalPrompt: string;
  recipient: string;
  amount: string; // e.g. "500.00"
  amountMinor: string; // e.g. "50000"
  currency: SupportedCurrency;
  purpose?: string;
  confidenceScore: number;
  requiresExplicitApproval: true; // Hardcoded invariant: Zero AI money movement
  provider?: 'gemini' | 'deterministic-fallback';
}

export interface FundingSourceOption {
  fundingWalletId: string;
  fundingCurrency: SupportedCurrency;
  fundingWalletName: string;
  availableBalanceMinor: string;
  availableBalanceFormatted: string;
  requiresConversion: boolean;
  conversionLabel: string; // e.g. "NGN → USD" or "Direct USD Transfer"
  exchangeRate?: number; // e.g. 1550.0 (NGN per USD)
  convertedDebitMinor: string; // Amount in funding currency
  convertedDebitFormatted: string;
  networkFeeMinor: string;
  networkFeeFormatted: string;
  fxFeeMinor: string;
  fxFeeFormatted: string;
  totalDebitMinor: string; // Converted debit + fees in funding currency
  totalDebitFormatted: string;
  targetPaymentMinor: string; // Delivered to recipient
  targetPaymentFormatted: string;
}

export interface BalanceInspectionResult {
  intent: TransferIntent;
  isDirectFunded: boolean;
  recommendedFundingOption?: FundingSourceOption;
  allFundingOptions: FundingSourceOption[];
  isPossible: boolean;
  reason?: string;
}

export interface TransferProposalPayload {
  proposalId: string;
  status: string;
  hashToSign: string;
  signPayload: string;
  expiresAt: string;
  fundingOption: FundingSourceOption;
  intent: TransferIntent;
}

export interface TransferExecuteResult {
  proposalId: string;
  status: string;
  transactionHash: string;
  timestamp: string;
  auditActivityId: string;
  details: {
    recipient: string;
    targetAmount: string;
    targetCurrency: SupportedCurrency;
    fundingWalletId: string;
    fundingCurrency: SupportedCurrency;
    totalDebited: string;
    conversionLabel: string;
    exchangeRate?: number;
    purpose?: string;
  };
}

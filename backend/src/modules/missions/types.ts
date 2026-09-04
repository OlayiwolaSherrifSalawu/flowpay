import type { SupportedCurrency } from '../../core/money.js';

export type MissionStatus =
  | 'DRAFT'
  | 'PENDING_APPROVAL'
  | 'ACTIVE'
  | 'PAUSED'
  | 'COMPLETED'
  | 'FAILED';

export type MissionIntentType =
  | 'SPLIT_INCOMING'
  | 'SAVE_GOAL'
  | 'CONVERT_FX'
  | 'SEND_MONEY'
  | 'RESERVE_TAX'
  | 'CUSTOM';

export type MissionAllocationCategory =
  | 'RESERVE'
  | 'EXPENSES'
  | 'TAX'
  | 'SAVINGS'
  | 'INVESTMENT'
  | 'CUSTOM';

export type MissionActionType =
  | 'HOLD'
  | 'CONVERT_FX'
  | 'SWEEP_VAULT'
  | 'TRANSFER';

export interface MissionAllocation {
  id: string;
  category: MissionAllocationCategory;
  label: string; // e.g. "USD Reserve", "NGN Expenses", "Tax Reserve"
  percentage: number; // e.g. 30, 50, 20
  targetCurrency: SupportedCurrency;
  sourceAmountMinor: string; // e.g. "60000" ($600.00)
  sourceAmountFormatted: string; // e.g. "$600.00"
  targetAmountMinor?: string; // e.g. "155000000"
  targetAmountFormatted?: string; // e.g. "$1,000 equivalent" or "₦1,550,000.00"
  destinationWalletTag: string; // e.g. "USD Smart Vault", "Main NGN Wallet", "Tax Escrow Reserve"
  actionType: MissionActionType;
  recipientIdentifier?: string; // e.g. if transferring
}

export interface MissionTriggerCondition {
  type: 'WHEN_RECEIVE' | 'BALANCE_THRESHOLD' | 'RECURRING_SCHEDULE' | 'MANUAL';
  sourceCurrency: SupportedCurrency;
  sourceAmount: string; // "2000.00"
  sourceAmountMinor: string; // "200000"
  description: string; // e.g. "Whenever I receive $2,000 USD"
}

export interface MissionIntent {
  intentId: string;
  originalPrompt: string;
  intentType: MissionIntentType;
  ruleTitle: string; // e.g. "Smart 3-Way Incoming Split"
  triggerCondition: MissionTriggerCondition;
  allocations: MissionAllocation[];
  destinationWallets: Record<string, string>;
  explanation: string;
  confidenceScore: number;
  requiresExplicitApproval: true; // Invariant: always true
  provider?: 'gemini' | 'deterministic-fallback';
}

export interface MissionValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export interface MissionProposalPayload {
  proposalId: string;
  missionId: string;
  ruleTitle: string;
  hashToSign: string; // 32-byte hex hash to be signed by BMONI B-Key
  signingInstructions: string;
  allocations: MissionAllocation[];
  createdAt: string;
}

export interface MissionExecutionResult {
  success: boolean;
  missionId: string;
  status: MissionStatus;
  executedAt: string;
  transactionReference: string;
  allocationsExecuted: number;
  auditId: string;
  summary: string;
}

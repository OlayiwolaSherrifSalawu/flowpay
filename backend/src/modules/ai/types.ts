import { type SupportedCurrency } from '../../core/money.js';

export interface CompletenessReport {
  score: number; // 0.0 - 1.0
  detectedActionCount: number;
  unresolvedActionCount: number;
  isReparseSuggested: boolean;
}

export type FinancialActionType =
  | 'SEND_MONEY'
  | 'CONVERT_CURRENCY'
  | 'ALLOCATE_MONEY'
  | 'CREATE_RESERVE'
  | 'UPDATE_RESERVE'
  | 'CREATE_MISSION'
  | 'UPDATE_MISSION'
  | 'CHECK_BALANCE'
  | 'CHECK_SPENDING'
  | 'CHECK_INCOME'
  | 'VIEW_TRANSACTIONS'
  | 'PAY_BENEFICIARY';

export interface BaseFinancialAction {
  id: string;
  type: FinancialActionType;
  description: string;
  dependsOn?: string[]; // IDs of preceding actions that must complete before this action
}

export interface SendMoneyAction extends BaseFinancialAction {
  type: 'SEND_MONEY';
  amount: string; // Major unit string e.g. "20.00"
  amountMinor: string; // Minor units e.g. "2000"
  currency: SupportedCurrency;
  recipient: string;
  destinationCountry?: string;
  destinationRail?: string;
  sourceWallet?: string;
}

export interface ConvertCurrencyAction extends BaseFinancialAction {
  type: 'CONVERT_CURRENCY';
  amount: string;
  amountMinor: string;
  sourceCurrency: SupportedCurrency;
  destinationCurrency: SupportedCurrency;
}

export interface AllocateMoneyAction extends BaseFinancialAction {
  type: 'ALLOCATE_MONEY';
  amount: string;
  amountMinor: string;
  currency: SupportedCurrency;
  destinationWallet: string;
  purpose?: string;
}

export interface CreateReserveAction extends BaseFinancialAction {
  type: 'CREATE_RESERVE';
  amount: string;
  amountMinor: string;
  currency: SupportedCurrency;
  purpose: string; // e.g. "tax", "emergency", "savings"
}

export interface UpdateReserveAction extends BaseFinancialAction {
  type: 'UPDATE_RESERVE';
  amount: string;
  amountMinor: string;
  currency: SupportedCurrency;
  purpose: string;
}

export interface CreateMissionAction extends BaseFinancialAction {
  type: 'CREATE_MISSION';
  rule: string;
  amount?: string;
  currency?: SupportedCurrency;
}

export interface UpdateMissionAction extends BaseFinancialAction {
  type: 'UPDATE_MISSION';
  missionId?: string;
  rule: string;
}

export interface CheckBalanceAction extends BaseFinancialAction {
  type: 'CHECK_BALANCE';
  currency?: SupportedCurrency;
}

export interface CheckSpendingAction extends BaseFinancialAction {
  type: 'CHECK_SPENDING';
  timeframe?: string;
}

export interface CheckIncomeAction extends BaseFinancialAction {
  type: 'CHECK_INCOME';
  timeframe?: string;
}

export interface ViewTransactionsAction extends BaseFinancialAction {
  type: 'VIEW_TRANSACTIONS';
  filter?: string;
}

export interface PayBeneficiaryAction extends BaseFinancialAction {
  type: 'PAY_BENEFICIARY';
  amount: string;
  amountMinor: string;
  currency: SupportedCurrency;
  beneficiaryId?: string;
  recipient: string;
}

export type FinancialAction =
  | SendMoneyAction
  | ConvertCurrencyAction
  | AllocateMoneyAction
  | CreateReserveAction
  | UpdateReserveAction
  | CreateMissionAction
  | UpdateMissionAction
  | CheckBalanceAction
  | CheckSpendingAction
  | CheckIncomeAction
  | ViewTransactionsAction
  | PayBeneficiaryAction;

export interface FinancialIntent {
  intentId: string;
  originalPrompt: string;
  actions: FinancialAction[];
  requiresClarification: boolean;
  clarificationQuestions: string[];
  completeness: CompletenessReport;
  explanation: string;
  confidenceScore: number;
  requiresExplicitApproval: true; // FlowPay invariant
  provider?: 'gemini' | 'deterministic-fallback';

  // Backward-compatibility properties for existing endpoints/tests
  operationType?: string;
  parameters?: {
    recipientIdentifier?: string;
    recipientUserId?: string;
    sourceCurrency: SupportedCurrency;
    targetCurrency?: SupportedCurrency;
    amountMinor?: string;
    amountFormatted?: string;
    description?: string;
  };
}

// Backwards-compatible alias
export type StructuredFinancialIntent = FinancialIntent;

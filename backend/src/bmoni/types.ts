/**
 * Type definitions matching the BMONI Embedded REST API
 */

export interface BmoniUser {
  id: string;
  email?: string;
  phoneNumber?: string;
  createdAt: string;
}

export interface OwnerProofChallenge {
  challengeId: string;
  message?: string;
  eip191Message?: string;
  expiresAt?: string;
}

export interface SmartWallet {
  id: string;
  address: string;
  currency: 'USDB' | 'CNGN' | 'CADC' | 'EURe' | 'GBPe' | 'MEXe';
  chain: string;
  status: 'active' | 'pending' | 'failed';
  userOwnerAddress: string;
  createdAt: string;
}

export interface WalletBalance {
  currency: string;
  balance: string; // decimal or minor depending on endpoint
  balanceMinor?: string;
  symbol?: string;
}

export interface Proposal {
  id: string;
  proposalId: string;
  status: 'PENDING_APPROVALS' | 'PENDING_SIGNATURES' | 'EXECUTED' | 'FAILED';
  method: 'evm';
  hashToSign?: string;
  signPayload?: string;
  deadline?: string;
  sourceSmartWalletId?: string;
  toUserId?: string;
  fromAmount?: string;
  token?: string;
}

export interface SignPayloadResponse {
  success: boolean;
  data: {
    method: string;
    walletIndex: number;
    workflowId: string;
    hashToSign: string;
    payload: string;
    deadline: string;
    proposalId: string;
  };
}

export interface CreateCardRequest {
  cardName: string;
  cardColor: string;
  currency: 'NGN' | 'USD';
  type: 'virtual' | 'physical';
  smartWalletId: string;
  nin?: string;
}

export interface CreateCardResponse {
  flow?: string;
  feeAmount?: string;
  feeCurrency?: string;
  proposalId?: string;
  proposalStatus?: string;
  signPayload?: Record<string, unknown> | string;
  signPayloadPending?: boolean;
  signPayloadHint?: string;
  signPayloadError?: string;
  migrationRequired?: boolean;
  migrationHint?: string;
  card?: BmoniCard;
}

export interface ProposalSignPayload {
  hashToSign: string;
  deadline?: string;
  safeTxHash?: string;
  userOpHash?: string;
  typedData?: Record<string, unknown>;
  isPending?: boolean;
}

export interface CardLedgerEntry {
  id: string;
  cardId: string;
  amount: string; // Minor-unit string e.g. "250000" = ₦2,500.00
  currency: string;
  description?: string;
  type?: string;
  timestamp: string;
}

export interface BmoniCard {
  id: string;
  userId: string;
  smartWalletId: string;
  cardName: string;
  cardColor: string;
  currency: 'NGN' | 'USD';
  type: 'virtual' | 'physical';
  status:
    | 'active'
    | 'frozen'
    | 'ACTIVE'
    | 'BLOCKED'
    | 'RESERVED'
    | 'pending'
    | 'inactive'
    | 'restricted'
    | 'lost'
    | 'stolen'
    | 'pending_activation'
    | 'terminated';
  isReserved?: boolean;
  proposalId?: string;
  proposalStatus?: string;
  last4?: string;
  maskedPan?: string;
  expirationDate?: string;
  balanceMinor?: string; // Minor-unit string e.g. "250000"
  ledger?: CardLedgerEntry[];
  spendLimit?: {
    dailyMinor?: number;
    monthlyMinor?: number;
  };
  createdAt: string;
}

export interface CardTransaction {
  id: string;
  cardId: string;
  amount: number; // Major-unit number e.g. 25.5 = $25.50
  amountMinor?: number; // Minor-unit compatibility fallback
  currency: string;
  merchantName: string;
  category?: string;
  status: 'settled' | 'pending' | 'declined' | 'COMPLETED';
  timestamp: string;
}

export interface EmployeeInviteRequest {
  name: string;
  email: string;
  country: string;
  kyc?: Record<string, unknown>;
}

export interface EmployeeInviteResponse {
  sent: boolean;
  inviteUrl: string;
  employeeId?: string;
}

export interface CreateUserRequest {
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber?: string;
}

export interface CreateUserResponse {
  bmoniUserId: string;
  id?: string;
  email?: string;
  phoneNumber?: string;
  createdAt?: string;
}

export interface WebhookSubscribeRequest {
  callbackUrl: string;
  events: string[];
  partnerId: string;
  active?: boolean;
}

export interface WebhookSubscribeResponse {
  id: string;
  partnerId: string;
  callbackUrl: string;
  secretKey: string;
  active: boolean;
  events: string[];
  createdAt: string;
  updatedAt: string;
}

export interface WebhookDeliveryPayload {
  id: string;
  eventType: string;
  payload: Record<string, unknown>;
  timestamp: string;
}

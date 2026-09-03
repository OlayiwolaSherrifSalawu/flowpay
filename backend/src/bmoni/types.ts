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
  eip191Message: string;
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

export interface BmoniCard {
  id: string;
  userId: string;
  smartWalletId: string;
  cardName: string;
  cardColor: string;
  currency: 'NGN' | 'USD';
  type: 'virtual' | 'physical';
  status: 'active' | 'frozen' | 'pending_activation' | 'terminated';
  last4?: string;
  maskedPan?: string;
  expirationDate?: string;
  spendLimit?: {
    dailyMinor?: number;
    monthlyMinor?: number;
  };
  createdAt: string;
}

export interface CardTransaction {
  id: string;
  cardId: string;
  amountMinor: number;
  currency: string;
  merchantName: string;
  category?: string;
  status: 'settled' | 'pending' | 'declined';
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

export interface WebhookDeliveryPayload {
  id: string;
  eventType: string;
  payload: Record<string, unknown>;
  timestamp: string;
}

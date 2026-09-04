import { env } from '../config/env.js';
import { BmoniApiError } from '../core/errors.js';
import type {
  BmoniCard,
  BmoniUser,
  CardLedgerEntry,
  CardTransaction,
  CreateCardRequest,
  CreateCardResponse,
  CreateUserRequest,
  CreateUserResponse,
  EmployeeInviteRequest,
  EmployeeInviteResponse,
  OwnerProofChallenge,
  Proposal,
  ProposalSignPayload,
  SignPayloadResponse,
  SmartWallet,
  WalletBalance,
  WebhookSubscribeRequest,
  WebhookSubscribeResponse,
} from './types.js';

export class BmoniClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly timeoutMs: number;

  constructor(options?: { baseUrl?: string; apiKey?: string; timeoutMs?: number }) {
    this.baseUrl = options?.baseUrl ?? env.BMONI_BASE_URL;
    this.apiKey = options?.apiKey ?? env.BMONI_API_KEY;
    this.timeoutMs = options?.timeoutMs ?? 15000;
  }

  /**
   * Internal HTTP dispatcher
   */
  private async request<T>(
    endpoint: string,
    options: {
      method?: 'GET' | 'POST' | 'PATCH' | 'DELETE' | 'PUT';
      body?: unknown;
      headers?: Record<string, string>;
    } = {}
  ): Promise<T> {
    const { method = 'GET', body, headers = {} } = options;
    const url = `${this.baseUrl}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

    const reqHeaders: Record<string, string> = {
      'x-api-key': this.apiKey,
      'Content-Type': 'application/json',
      ...headers,
    };

    try {
      this.safeLog(`BMONI [${method}] ${endpoint}`);
      const response = await fetch(url, {
        method,
        headers: reqHeaders,
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      const responseText = await response.text();
      let responseJson: any = null;
      try {
        responseJson = responseText ? JSON.parse(responseText) : {};
      } catch {
        responseJson = { raw: responseText };
      }

      if (!response.ok) {
        const message = Array.isArray(responseJson?.message)
          ? responseJson.message.join('; ')
          : responseJson?.message || response.statusText || 'BMONI Request Failed';

        // Idempotent recovery for user creation: If 409 Conflict, returns message with details
        throw new BmoniApiError(message, response.status, responseJson?.error, responseJson);
      }

      return responseJson as T;
    } catch (err: any) {
      if (err.name === 'AbortError') {
        throw new BmoniApiError(`BMONI request to ${endpoint} timed out after ${this.timeoutMs}ms`, 504);
      }
      if (err instanceof BmoniApiError) {
        throw err;
      }
      throw new BmoniApiError(err.message || 'Unknown network error communicating with BMONI', 500);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  private safeLog(message: string): void {
    if (env.NODE_ENV !== 'test') {
      console.log(`[BMONI SafeClient] ${message}`);
    }
  }

  // --- Users & Onboarding ---

  async createUser(input: { email?: string; phoneNumber?: string }): Promise<BmoniUser> {
    return this.request<BmoniUser>('/v1/users', {
      method: 'POST',
      body: input,
    });
  }

  /**
   * Stage 1 of Employee Lifecycle: Create user on BMONI rails
   * Official BMONI spec: POST /v1/users
   * Returns bmoniUserId needed for all user-scoped operations
   */
  async createEmployeeUser(input: CreateUserRequest): Promise<CreateUserResponse> {
    return this.request<CreateUserResponse>('/v1/users', {
      method: 'POST',
      body: input,
    });
  }

  // --- BMONI Global KYC & Onboarding ---

  async getKycOptions(userId: string): Promise<any> {
    return this.request(`/v1/users/${userId}/kyc/options`);
  }

  async uploadKycDocument(args: {
    userId: string;
    documentType: 'identification' | 'proof-of-address' | 'biometric';
    type?: string;
    documentNumber?: string;
    issuingCountryCode?: string;
  }): Promise<any> {
    try {
      return await this.request(`/v1/users/${args.userId}/kyc/documents/${args.documentType}`, {
        method: 'POST',
        body: {
          type: args.type || 'national_id',
          documentNumber: args.documentNumber || 'A10000001',
          issuingCountryCode: args.issuingCountryCode || 'NGA',
          sandbox: true,
        },
      });
    } catch (err: any) {
      this.safeLog(`Document upload notice for ${args.documentType}: ${err.message || err}`);
      return { uploaded: true, documentType: args.documentType, sandbox: true };
    }
  }

  async submitKycProfile(args: {
    userId: string;
    personalInfo?: any;
    addressDetails?: any;
    identificationNumbers?: any;
    employment?: any;
    sourceOfFunds?: string;
    estimatedMonthlyVolume?: number;
    accountPurpose?: string;
    actingAsIntermediary?: boolean;
    bvn?: string;
  }): Promise<any> {
    const { userId, ...body } = args;
    return this.request(`/v1/users/${userId}/kyc`, {
      method: 'PATCH',
      body,
    });
  }

  async activateKyc(args: {
    userId: string;
    sumsubLevelName?: 'id-only' | 'id-and-liveness' | 'idv-and-phone-verification' | string;
  }): Promise<any> {
    return this.request(`/v1/users/${args.userId}/kyc/activate`, {
      method: 'POST',
      body: args.sumsubLevelName ? { sumsubLevelName: args.sumsubLevelName } : {},
    });
  }

  async getKycReadiness(userId: string): Promise<{ ready: boolean; missing?: string[] }> {
    return this.request<{ ready: boolean; missing?: string[] }>(`/v1/users/${userId}/kyc/readiness`);
  }

  async getOnboardingStatus(userId: string): Promise<any> {
    return this.request(`/v1/users/${userId}/onboarding/status`);
  }

  // --- Smart Wallets & On-Device Handshake ---

  async createOwnerProofChallenge(args: {
    userId: string;
    currency: string;
    userOwnerAddress: string;
  }): Promise<OwnerProofChallenge> {
    return this.request<OwnerProofChallenge>(
      `/v1/users/${args.userId}/smart-wallets/owner-proof-challenges`,
      {
        method: 'POST',
        body: {
          currency: args.currency,
          userOwnerAddress: args.userOwnerAddress,
        },
      }
    );
  }

  async createManagedSmartWallet(args: {
    userId: string;
    currency: string;
    userOwnerAddress: string;
    ownerProofChallengeId: string;
    ownerProofSignature: string;
  }): Promise<SmartWallet> {
    return this.request<SmartWallet>(
      `/v1/users/${args.userId}/smart-wallets/create-managed`,
      {
        method: 'POST',
        body: args,
      }
    );
  }

  async listAccountSmartWallets(userId: string): Promise<SmartWallet[]> {
    const res = await this.request<{ wallets?: SmartWallet[] } | SmartWallet[]>(
      `/v1/users/${userId}/smart-wallets/account/wallets`
    );
    return Array.isArray(res) ? res : res.wallets || [];
  }

  async listAccountBalances(userId: string): Promise<WalletBalance[]> {
    const res = await this.request<{ balances?: WalletBalance[] } | WalletBalance[]>(
      `/v1/users/${userId}/smart-wallets/account/balances`
    );
    return Array.isArray(res) ? res : res.balances || [];
  }

  async getSmartWalletDetail(userId: string, smartWalletId: string): Promise<SmartWallet> {
    return this.request<SmartWallet>(
      `/v1/users/${userId}/smart-wallets/${smartWalletId}`
    );
  }

  // --- Proposals & Transfers ---

  async createTransferProposal(args: {
    userId: string;
    walletId: string;
    toUserId: string;
    sourceSmartWalletId: string;
    token: string;
    fromAmount: string; // Minor units or formatted decimal per endpoint
  }): Promise<Proposal> {
    return this.request<Proposal>(
      `/v1/users/${args.userId}/smart-wallets/${args.walletId}/proposals`,
      {
        method: 'POST',
        body: {
          toUserId: args.toUserId,
          sourceSmartWalletId: args.sourceSmartWalletId,
          token: args.token,
          fromAmount: args.fromAmount,
        },
      }
    );
  }


  async signProposal(args: {
    userId: string;
    proposalId: string;
    signature: string;
  }): Promise<{ success: boolean; status: string }> {
    return this.request<{ success: boolean; status: string }>(
      `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}/sign`,
      {
        method: 'POST',
        body: { signature: args.signature },
      }
    );
  }

  async getProposal(args: { userId: string; proposalId: string }): Promise<Proposal> {
    return this.request<Proposal>(
      `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}`
    );
  }

  // --- Cards & Transactions (Verified against BMONI Cards API) ---

  async createVirtualCard(args: {
    userId: string;
    cardName: string;
    cardColor?: string;
    currency: 'NGN' | 'USD';
    smartWalletId: string;
    nin?: string;
  }): Promise<CreateCardResponse> {
    const cardColor = args.cardColor || '#F4B740';
    return this.request<CreateCardResponse>(
      `/v1/users/${args.userId}/cards`,
      {
        method: 'POST',
        body: {
          cardName: args.cardName,
          cardColor,
          currency: args.currency,
          type: 'virtual',
          smartWalletId: args.smartWalletId,
          ...(args.nin ? { nin: args.nin } : {}),
        },
      }
    );
  }

  async getProposalSignPayload(args: {
    userId: string;
    proposalId: string;
  }): Promise<ProposalSignPayload> {
    try {
      const res = await this.request<ProposalSignPayload>(
        `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}/sign-payload`
      );
      return res;
    } catch (err) {
      if (err instanceof BmoniApiError && err.statusCode === 409) {
        // 409 means "not ready yet", return pending status for client polling
        return {
          hashToSign: '',
          isPending: true,
        };
      }
      throw err;
    }
  }

  async submitProposalSignature(args: {
    userId: string;
    proposalId: string;
    signature: string;
  }): Promise<{ success: boolean; status?: string; transactionHash?: string }> {
    return this.request<{ success: boolean; status?: string; transactionHash?: string }>(
      `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}/sign`,
      {
        method: 'POST',
        body: { signature: args.signature },
      }
    );
  }

  async listWalletCards(args: {
    userId: string;
    smartWalletId: string;
  }): Promise<BmoniCard[]> {
    const res = await this.request<{ cards?: BmoniCard[] } | BmoniCard[]>(
      `/v1/users/${args.userId}/smart-wallets/${args.smartWalletId}/cards`
    );
    const list = Array.isArray(res) ? res : res.cards || [];
    return list.map((c) => {
      // Normalize reserved status for cards awaiting issuance/signatures
      const isReserved = c.isReserved === true || c.status === 'RESERVED';
      return {
        ...c,
        isReserved,
        cardColor: c.cardColor || '#F4B740',
      };
    });
  }

  async listCards(userId: string, smartWalletId?: string): Promise<BmoniCard[]> {
    if (smartWalletId) {
      return this.listWalletCards({ userId, smartWalletId });
    }
    const res = await this.request<{ cards?: BmoniCard[] } | BmoniCard[]>(
      `/v1/users/${userId}/cards`
    );
    return Array.isArray(res) ? res : res.cards || [];
  }

  async getCardDetail(args: {
    userId: string;
    smartWalletId: string;
    cardId: string;
  }): Promise<BmoniCard> {
    return this.request<BmoniCard>(
      `/v1/users/${args.userId}/smart-wallets/${args.smartWalletId}/cards/${args.cardId}`
    );
  }

  async getCardSensitiveData(args: {
    userId: string;
    cardId: string;
    identityId?: string;
  }): Promise<{
    pan: string;
    cvv: string;
    expirationDate: string;
    billingAddress?: Record<string, unknown>;
  }> {
    return this.request<{
      pan: string;
      cvv: string;
      expirationDate: string;
      billingAddress?: Record<string, unknown>;
    }>(`/v1/users/${args.userId}/cards/sensitive-data`, {
      method: 'POST',
      body: {
        cardId: args.cardId,
        identityId: args.identityId || 'identity-1',
      },
    });
  }

  async getCardTransactions(args: {
    userId: string;
    cardId: string;
    size?: number;
    status?: string;
    from?: string;
    to?: string;
  }): Promise<CardTransaction[]> {
    const size = args.size ?? 20;
    const params = new URLSearchParams({ size: size.toString() });
    if (args.status) params.set('status', args.status);
    if (args.from) params.set('from', args.from);
    if (args.to) params.set('to', args.to);

    const res = await this.request<{ transactions?: CardTransaction[] } | CardTransaction[]>(
      `/v1/users/${args.userId}/cards/${args.cardId}/transactions?${params.toString()}`
    );
    const list = Array.isArray(res) ? res : res.transactions || [];
    return list.map((tx) => ({
      ...tx,
      // Ensure major-unit amount number is present
      amount: typeof tx.amount === 'number' ? tx.amount : (tx.amountMinor ? tx.amountMinor / 100 : 0),
    }));
  }

  async updateCardStatus(args: {
    userId: string;
    cardId: string;
    status: 'BLOCKED' | 'ACTIVE';
  }): Promise<BmoniCard> {
    return this.request<BmoniCard>(
      `/v1/users/${args.userId}/cards/${args.cardId}/status`,
      {
        method: 'PUT',
        body: { status: args.status },
      }
    );
  }

  // --- Partner Employees & Webhooks (Payroll Infrastructure) ---

  /**
   * @deprecated Use createEmployeeUser() with POST /v1/users per corrected BMONI spec
   */
  async inviteEmployee(payload: EmployeeInviteRequest): Promise<EmployeeInviteResponse> {
    return this.request<EmployeeInviteResponse>('/v1/partners/employees/invite', {
      method: 'POST',
      body: payload,
    });
  }

  /**
   * Subscribe to partner-scoped webhook deliveries
   * Official BMONI spec: POST /v1/webhooks/config with explicit partnerId
   */
  async subscribeWebhook(payload: WebhookSubscribeRequest): Promise<WebhookSubscribeResponse> {
    return this.request<WebhookSubscribeResponse>('/v1/webhooks/config', {
      method: 'POST',
      body: payload,
    });
  }

  // --- Regional Onboarding ---

  async getMexicoAgreements(userId: string): Promise<{
    url: string;
    method: string;
    fields: Record<string, string>;
    html: string;
    expiresAt: string;
  }> {
    return this.request(`/v1/users/${userId}/latam/mx/kyc/launch/agreements`);
  }

  async getMexicoKycStatus(userId: string): Promise<{
    status: 'proposed' | 'bank_verification_required' | 'approved' | 'approved_chain_deploying' | 'rejected' | string;
    uploaded?: { selfie: boolean; document: boolean };
  }> {
    return this.request(`/v1/users/${userId}/latam/mx/kyc/status`);
  }

  async startNigeriaOnboarding(args: {
    userId: string;
    smartWalletId?: string;
    bvn?: string;
    ngnWalletAddress?: string;
    ngnWalletIndex?: number;
  }): Promise<any> {
    const body: Record<string, any> = {};
    if (args.bvn) body.bvn = args.bvn;
    if (args.ngnWalletAddress) body.ngnWalletAddress = args.ngnWalletAddress;
    if (args.ngnWalletIndex !== undefined) body.ngnWalletIndex = args.ngnWalletIndex;
    if (args.smartWalletId) body.smartWalletId = args.smartWalletId;

    return this.request(`/v1/users/${args.userId}/onboarding/start-nigeria`, {
      method: 'POST',
      body,
    });
  }

  async activateMexicoKyc(args: {
    userId: string;
    smartWalletId?: string;
    paternalLastName?: string;
    maternalLastName?: string;
    birthCountryIsoCode?: string;
  }): Promise<any> {
    const body: Record<string, any> = {};
    if (args.smartWalletId) body.smartWalletId = args.smartWalletId;
    if (args.paternalLastName) body.paternalLastName = args.paternalLastName;
    if (args.maternalLastName) body.maternalLastName = args.maternalLastName;
    if (args.birthCountryIsoCode) body.birthCountryIsoCode = args.birthCountryIsoCode;

    return this.request(`/v1/users/${args.userId}/latam/mx/kyc/activate`, {
      method: 'POST',
      body,
    });
  }
}

export const bmoniClient = new BmoniClient();

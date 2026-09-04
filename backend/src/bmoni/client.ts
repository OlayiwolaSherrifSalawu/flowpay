import { env } from '../config/env.js';
import { BmoniApiError } from '../core/errors.js';
import type {
  BmoniCard,
  BmoniUser,
  CardTransaction,
  CreateUserRequest,
  CreateUserResponse,
  EmployeeInviteRequest,
  EmployeeInviteResponse,
  OwnerProofChallenge,
  Proposal,
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

  async submitKycProfile(args: {
    userId: string;
    personalInfo: {
      firstName: string;
      lastName: string;
      dateOfBirth: string;
      gender?: string;
    };
    addressDetails: {
      street: string;
      city: string;
      state: string;
      countryCode: string;
    };
    identificationNumbers?: Record<string, string>;
  }): Promise<any> {
    return this.request(`/v1/users/${args.userId}/kyc`, {
      method: 'PATCH',
      body: {
        personalInfo: args.personalInfo,
        addressDetails: args.addressDetails,
        identificationNumbers: args.identificationNumbers,
      },
    });
  }

  async activateKyc(args: {
    userId: string;
    sumsubLevelName?: 'id-only' | 'id-and-liveness' | 'idv-and-phone-verification';
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

  // --- Proposals & Transfers ---

  async createTransferProposal(args: {
    userId: string;
    walletId: string;
    toUserId?: string;
    toAddress?: string;
    token?: string;
    currency?: string;
    amount?: string;
    fromAmount?: string;
    description?: string;
    sourceSmartWalletId?: string;
  }): Promise<Proposal> {
    const currency = args.currency || args.token || 'USDB';
    const amount = args.amount || args.fromAmount || '0.00';

    const proposalBody: Record<string, any> = {
      type: 'TRANSFER',
      amount,
      currency,
    };

    if (args.toAddress) {
      proposalBody.toAddress = args.toAddress;
    } else if (args.toUserId) {
      proposalBody.toUserId = args.toUserId;
    }

    if (args.description) {
      proposalBody.description = args.description;
    }

    return this.request<Proposal>(
      `/v1/users/${args.userId}/smart-wallets/${args.walletId}/proposals`,
      {
        method: 'POST',
        body: {
          proposal: proposalBody,
        },
      }
    );
  }

  async createSwapProposal(args: {
    userId: string;
    walletId: string;
    fromStablecoin: string;
    toStablecoin: string;
    fromAmount: string;
    slippageBps?: number;
  }): Promise<Proposal> {
    return this.request<Proposal>(
      `/v1/users/${args.userId}/smart-wallets/${args.walletId}/proposals`,
      {
        method: 'POST',
        body: {
          proposal: {
            type: 'SWAP',
            fromStablecoin: args.fromStablecoin,
            toStablecoin: args.toStablecoin,
            fromAmount: args.fromAmount,
            slippageBps: args.slippageBps ?? 50,
          },
        },
      }
    );
  }

  async approveProposal(args: {
    userId: string;
    proposalId: string;
  }): Promise<{ success: boolean; status: string }> {
    return this.request<{ success: boolean; status: string }>(
      `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}/approve`,
      {
        method: 'POST',
      }
    );
  }

  async getProposalSignPayload(args: {
    userId: string;
    proposalId: string;
  }): Promise<SignPayloadResponse> {
    return this.request<SignPayloadResponse>(
      `/v1/users/${args.userId}/smart-wallets/proposals/${args.proposalId}/sign-payload`
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

  // --- Cards & Transactions ---

  async createVirtualCard(args: {
    userId: string;
    cardName: string;
    cardColor: string;
    currency: 'NGN' | 'USD';
    smartWalletId: string;
    nin?: string;
  }): Promise<{ card: BmoniCard; proposalId?: string; signPayload?: string }> {
    return this.request<{ card: BmoniCard; proposalId?: string; signPayload?: string }>(
      `/v1/users/${args.userId}/cards`,
      {
        method: 'POST',
        body: {
          cardName: args.cardName,
          cardColor: args.cardColor,
          currency: args.currency,
          type: 'virtual',
          smartWalletId: args.smartWalletId,
          nin: args.nin,
        },
      }
    );
  }

  async listCards(userId: string): Promise<BmoniCard[]> {
    const res = await this.request<{ cards?: BmoniCard[] } | BmoniCard[]>(
      `/v1/users/${userId}/cards`
    );
    return Array.isArray(res) ? res : res.cards || [];
  }

  async getCardTransactions(args: {
    userId: string;
    cardId: string;
    size?: number;
  }): Promise<CardTransaction[]> {
    const size = args.size ?? 20;
    const res = await this.request<{ transactions?: CardTransaction[] } | CardTransaction[]>(
      `/v1/users/${args.userId}/cards/${args.cardId}/transactions?size=${size}`
    );
    return Array.isArray(res) ? res : res.transactions || [];
  }

  async updateCardStatus(args: {
    userId: string;
    cardId: string;
    status: 'frozen' | 'active' | 'terminated';
  }): Promise<BmoniCard> {
    return this.request<BmoniCard>(
      `/v1/users/${args.userId}/cards/${args.cardId}/status`,
      {
        method: 'PATCH',
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

  async startNigeriaOnboarding(args: {
    userId: string;
    smartWalletId: string;
    bvn?: string;
  }): Promise<any> {
    return this.request(`/v1/users/${args.userId}/onboarding/start-nigeria`, {
      method: 'POST',
      body: {
        smartWalletId: args.smartWalletId,
        bvn: args.bvn ?? '22222222222', // Default to sandbox test BVN
      },
    });
  }

  async activateMexicoKyc(args: {
    userId: string;
    smartWalletId: string;
  }): Promise<any> {
    return this.request(`/v1/users/${args.userId}/latam/mx/kyc/activate`, {
      method: 'POST',
      body: { smartWalletId: args.smartWalletId },
    });
  }
}

export const bmoniClient = new BmoniClient();

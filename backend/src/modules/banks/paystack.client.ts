import { env } from '../../config/env.js';
import { FlowPayError } from '../../core/errors.js';

export interface PaystackBank {
  id: number;
  name: string;
  code: string;
  slug: string;
  longcode?: string;
  country: string;
  currency: string;
  isPopular: boolean;
}

export interface ResolvedAccount {
  accountNumber: string;
  accountName: string;
  bankCode: string;
  bankName: string;
  bankId?: number;
  isSimulated?: boolean;
  testNotice?: string;
}

// Popular Nigerian banks prioritized in mobile UX
const POPULAR_NIGERIAN_BANK_CODES = new Set([
  '058',    // Guaranty Trust Bank (GTB)
  '999992', // OPay Digital Services
  '044',    // Access Bank
  '057',    // Zenith Bank
  '50211',  // Kuda Bank
  '999991', // PalmPay
  '011',    // First Bank of Nigeria
  '033',    // United Bank For Africa (UBA)
  '50515',  // Moniepoint MFB
  '035',    // Wema Bank / ALAT
  '221',    // Stanbic IBTC Bank
  '070',    // Fidelity Bank
  '214',    // First City Monument Bank (FCMB)
  '082',    // Keystone Bank
  '001',    // Paystack Test Bank
]);

export class PaystackBankService {
  private static cachedBanks: Map<string, { timestamp: number; banks: PaystackBank[] }> = new Map();
  private static readonly CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

  /**
   * Fetch and cache list of banks (defaulting to Nigeria).
   * Popular commercial banks and fintechs are surfaced first.
   */
  static async listBanks(options: { country?: string; search?: string } = {}): Promise<PaystackBank[]> {
    const country = (options.country || 'nigeria').toLowerCase();
    const cacheKey = country;
    const now = Date.now();

    let banks: PaystackBank[] = [];
    const cached = this.cachedBanks.get(cacheKey);

    if (cached && now - cached.timestamp < this.CACHE_TTL_MS) {
      banks = cached.banks;
    } else {
      try {
        const url = `${env.PAYSTACK_BASE_URL}/bank?country=${encodeURIComponent(country)}`;
        const headers: Record<string, string> = {
          'Content-Type': 'application/json',
        };
        if (env.PAYSTACK_SECRET_KEY) {
          headers['Authorization'] = `Bearer ${env.PAYSTACK_SECRET_KEY}`;
        }

        const res = await fetch(url, { headers });
        if (!res.ok) {
          throw new Error(`Paystack bank list returned HTTP ${res.status}`);
        }

        const json: any = await res.json();
        if (json.status && Array.isArray(json.data)) {
          banks = json.data.map((b: any) => ({
            id: b.id,
            name: b.name,
            code: b.code,
            slug: b.slug,
            longcode: b.longcode,
            country: b.country || 'Nigeria',
            currency: b.currency || 'NGN',
            isPopular: POPULAR_NIGERIAN_BANK_CODES.has(b.code),
          }));

          // Sort: Popular banks first, then alphabetical by name
          banks.sort((a, b) => {
            if (a.isPopular && !b.isPopular) return -1;
            if (!a.isPopular && b.isPopular) return 1;
            return a.name.localeCompare(b.name);
          });

          this.cachedBanks.set(cacheKey, { timestamp: now, banks });
        }
      } catch (err: any) {
        console.warn('[PaystackBankService] Failed to fetch live bank list from Paystack:', err.message);
        if (cached) {
          // Serve stale cache on network failure
          banks = cached.banks;
        } else {
          // Fallback minimal bank list if Paystack API is unreachable
          banks = this.getStaticFallbackBanks();
        }
      }
    }

    if (options.search && options.search.trim()) {
      const q = options.search.trim().toLowerCase();
      return banks.filter(
        (b) => b.name.toLowerCase().includes(q) || b.code.includes(q) || b.slug.toLowerCase().includes(q)
      );
    }

    return banks;
  }

  /**
   * Resolve a bank account number (NUBAN) with Paystack
   * Endpoint: GET /bank/resolve?account_number=...&bank_code=...
   */
  static async resolveAccount(accountNumber: string, bankCode: string): Promise<ResolvedAccount> {
    const cleanAccount = accountNumber.trim().replace(/\D/g, '');
    const cleanBankCode = bankCode.trim();

    if (cleanAccount.length !== 10) {
      throw new FlowPayError(
        'Nigerian bank account numbers must be exactly 10 digits (NUBAN format).',
        400,
        'INVALID_ACCOUNT_NUMBER'
      );
    }

    if (!cleanBankCode) {
      throw new FlowPayError(
        'Bank code is required to resolve account details.',
        400,
        'MISSING_BANK_CODE'
      );
    }

    // Lookup bank name from cached banks list
    const banks = await this.listBanks();
    const matchedBank = banks.find((b) => b.code === cleanBankCode);
    const bankName = matchedBank ? matchedBank.name : `Bank (${cleanBankCode})`;

    // If no Paystack secret key is configured, provide deterministic sandbox resolution
    if (!env.PAYSTACK_SECRET_KEY) {
      return {
        accountNumber: cleanAccount,
        accountName: this.deriveSandboxAccountName(cleanAccount, bankName),
        bankCode: cleanBankCode,
        bankName,
        isSimulated: true,
        testNotice: 'Resolved in FlowPay sandbox simulation mode (no PAYSTACK_SECRET_KEY configured).',
      };
    }

    const isTestKey = env.PAYSTACK_SECRET_KEY.startsWith('sk_test_');

    try {
      const url = `${env.PAYSTACK_BASE_URL}/bank/resolve?account_number=${cleanAccount}&bank_code=${cleanBankCode}`;
      const res = await fetch(url, {
        headers: {
          Authorization: `Bearer ${env.PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      });

      const json: any = await res.json();

      if (json.status === true && json.data) {
        return {
          accountNumber: json.data.account_number,
          accountName: json.data.account_name,
          bankCode: cleanBankCode,
          bankName,
          bankId: json.data.bank_id,
        };
      }

      // Check if Paystack returned test mode daily limit message
      const errMsg = json.message || '';
      if (isTestKey && (errMsg.includes('daily limit') || errMsg.includes('Test mode'))) {
        console.warn(`[PaystackBankService] Paystack test mode notice: ${errMsg}. Providing test resolution.`);
        return {
          accountNumber: cleanAccount,
          accountName: this.deriveSandboxAccountName(cleanAccount, bankName),
          bankCode: cleanBankCode,
          bankName,
          isSimulated: true,
          testNotice: `Paystack test mode daily limit reached. Test simulation active for ${cleanAccount}.`,
        };
      }

      // Real error from Paystack
      throw new FlowPayError(
        json.message || 'Could not resolve account name with the provided bank.',
        res.status === 404 || res.status === 422 ? 404 : 400,
        'ACCOUNT_RESOLUTION_FAILED',
        json.meta || json.type
      );
    } catch (err: any) {
      if (err instanceof FlowPayError) throw err;

      // Handle unexpected network/connection failures
      console.error('[PaystackBankService] Error calling Paystack resolve API:', err.message || err);
      if (isTestKey) {
        return {
          accountNumber: cleanAccount,
          accountName: this.deriveSandboxAccountName(cleanAccount, bankName),
          bankCode: cleanBankCode,
          bankName,
          isSimulated: true,
          testNotice: 'Network fallback test resolution (sk_test key active).',
        };
      }

      throw new FlowPayError(
        'Unable to reach bank verification provider. Please try again shortly.',
        502,
        'PAYSTACK_UNAVAILABLE'
      );
    }
  }

  /**
   * Deterministic test account name derivation for demo and test mode
   */
  private static deriveSandboxAccountName(accountNumber: string, bankName: string): string {
    const knownNames: Record<string, string> = {
      '0000000000': 'FLOWPAY MASTER TEST BENEFICIARY',
      '0001234567': 'ADEKUNLE CIROMA CHUKWUMA',
      '0123456789': 'BUNCH DILLON ENTERPRISES',
      '9999999999': 'SAMSON JABO TECH LTD',
    };

    if (knownNames[accountNumber]) {
      return knownNames[accountNumber];
    }

    // Synthesize realistic name based on the last 4 digits
    const suffixes = ['EMMANUEL ADEBAYO', 'CHIDINMA OKONKWO', 'FATIMA BELLO', 'BABATUNDE BAKARE', 'NGOZI EZE'];
    const index = parseInt(accountNumber.slice(-2), 10) % suffixes.length;
    return `${suffixes[index]} / ${bankName.toUpperCase()}`;
  }

  /**
   * Static fallback list if Paystack API is initially unreachable
   */
  private static getStaticFallbackBanks(): PaystackBank[] {
    return [
      { id: 9, name: 'Guaranty Trust Bank', code: '058', slug: 'guaranty-trust-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 295, name: 'OPay Digital Services Limited (OPay)', code: '999992', slug: 'opay', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 1, name: 'Access Bank', code: '044', slug: 'access-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 21, name: 'Zenith Bank', code: '057', slug: 'zenith-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 67, name: 'Kuda Bank', code: '50211', slug: 'kuda-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 294, name: 'PalmPay', code: '999991', slug: 'palmpay', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 7, name: 'First Bank of Nigeria', code: '011', slug: 'first-bank-of-nigeria', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 18, name: 'United Bank For Africa', code: '033', slug: 'united-bank-for-africa', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 200, name: 'Moniepoint MFB', code: '50515', slug: 'moniepoint-mfb', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 20, name: 'Wema Bank', code: '035', slug: 'wema-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 16, name: 'Stanbic IBTC Bank', code: '221', slug: 'stanbic-ibtc-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 6, name: 'Fidelity Bank', code: '070', slug: 'fidelity-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 8, name: 'First City Monument Bank', code: '214', slug: 'first-city-monument-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
      { id: 24, name: 'Test Bank', code: '001', slug: 'test-bank', country: 'Nigeria', currency: 'NGN', isPopular: true },
    ];
  }
}

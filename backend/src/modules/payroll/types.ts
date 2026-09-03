export interface PayrollEmployeeAllocation {
  employeeId: string;
  name: string;
  email: string;
  country: 'NG' | 'MX' | 'CA' | 'US';
  targetCurrency: 'NGN' | 'MXN' | 'CAD' | 'USD';
  targetAmountMinor: number; // e.g. 3,100,000 NGN in kobo (310000000) or 34,000 MXN in centavos (3400000)
  usdAmountMinor: number;    // Equivalent in USD cents
  exchangeRate: number;      // e.g. 1550 NGN/USD or 17.5 MXN/USD
  walletId?: string;
  bmoniUserId?: string;
}

export interface PayrollRunSummary {
  runId: string;
  title: string;
  totalUsdMinor: number;
  totalUsdFormatted: string;
  totalFeeUsdMinor: number;
  totalFeeUsdFormatted: string;
  employeeCount: number;
  countriesCount: number;
  countries: string[];
  currencies: string[];
  items: Array<{
    employeeId: string;
    name: string;
    country: string;
    targetCurrency: string;
    targetAmountFormatted: string;
    usdAmountFormatted: string;
    exchangeRate: number;
    status: 'SUCCESS' | 'FAILED' | 'PENDING';
    proposalId?: string;
    transactionHash?: string;
  }>;
  status: 'COMPLETED' | 'FAILED' | 'PARTIAL';
  executedAt: string;
}

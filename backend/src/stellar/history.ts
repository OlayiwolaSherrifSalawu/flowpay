import { Horizon } from '@stellar/stellar-sdk';
import { currencyForAsset, explorerTxUrl, getNetworkConfig, type StellarCurrency } from './config.js';
import { mapHorizonError } from './horizon.js';
import { assertAccountId } from './accounts.js';

/** One money movement touching an account, normalized from Horizon payment operations. */
export interface PaymentHistoryItem {
  id: string;
  pagingToken: string;
  type: 'payment' | 'path_payment' | 'account_created';
  direction: 'incoming' | 'outgoing' | 'self';
  counterparty: string;
  /** Amount from this account's point of view (received if incoming, sent if outgoing). */
  amount: string;
  currency: StellarCurrency | 'XLM' | string;
  /** For path payments: the other side's asset and amount. */
  counterAmount?: string;
  counterCurrency?: string;
  transactionHash: string;
  explorerUrl: string;
  createdAt: string;
  successful: boolean;
  memo?: string;
}

function label(code?: string, issuer?: string, type?: string): string {
  if (type === 'native' || !code) return 'XLM';
  return (issuer && currencyForAsset(code, issuer)) || code;
}

/** Pure mapping, unit-tested. Returns null for operations FlowPay doesn't display. */
export function mapPaymentRecord(accountId: string, r: any): PaymentHistoryItem | null {
  const base = {
    id: r.id,
    pagingToken: r.paging_token,
    transactionHash: r.transaction_hash,
    explorerUrl: explorerTxUrl(r.transaction_hash),
    createdAt: r.created_at,
    successful: r.transaction_successful !== false,
    memo: r.transaction?.memo_type === 'text' ? r.transaction.memo : undefined,
  };

  if (r.type === 'create_account') {
    const incoming = r.account === accountId;
    return { ...base, type: 'account_created', direction: incoming ? 'incoming' : 'outgoing', counterparty: incoming ? r.funder : r.account, amount: r.starting_balance, currency: 'XLM' };
  }

  if (r.type === 'payment') {
    const incoming = r.to === accountId;
    const outgoing = r.from === accountId;
    return {
      ...base,
      type: 'payment',
      direction: incoming && outgoing ? 'self' : incoming ? 'incoming' : 'outgoing',
      counterparty: incoming ? r.from : r.to,
      amount: r.amount,
      currency: label(r.asset_code, r.asset_issuer, r.asset_type),
    };
  }

  if (r.type === 'path_payment_strict_receive' || r.type === 'path_payment_strict_send') {
    const incoming = r.to === accountId;
    const outgoing = r.from === accountId;
    const received = { amount: r.amount, currency: label(r.asset_code, r.asset_issuer, r.asset_type) };
    const sent = { amount: r.source_amount, currency: label(r.source_asset_code, r.source_asset_issuer, r.source_asset_type) };
    const mine = incoming && !outgoing ? received : sent;
    const theirs = incoming && !outgoing ? sent : received;
    return {
      ...base,
      type: 'path_payment',
      direction: incoming && outgoing ? 'self' : incoming ? 'incoming' : 'outgoing',
      counterparty: incoming ? r.from : r.to,
      amount: mine.amount,
      currency: mine.currency,
      counterAmount: theirs.amount,
      counterCurrency: theirs.currency,
    };
  }
  return null;
}

export async function fetchPaymentHistory(
  accountId: string,
  opts: { limit?: number; cursor?: string; server?: Horizon.Server } = {}
): Promise<{ items: PaymentHistoryItem[]; nextCursor: string | null }> {
  assertAccountId(accountId);
  const server = opts.server ?? new Horizon.Server(getNetworkConfig().horizonUrl);
  const limit = Math.min(Math.max(opts.limit ?? 30, 1), 100);
  try {
    let call = server.payments().forAccount(accountId).order('desc').limit(limit).join('transactions');
    if (opts.cursor) call = call.cursor(opts.cursor);
    const page = await call.call();
    const items = page.records.map((r) => mapPaymentRecord(accountId, r)).filter((x): x is PaymentHistoryItem => x !== null);
    return { items, nextCursor: page.records.length === limit ? page.records[page.records.length - 1].paging_token : null };
  } catch (err) {
    if ((err as any)?.response?.status === 404) return { items: [], nextCursor: null };
    throw mapHorizonError(err);
  }
}

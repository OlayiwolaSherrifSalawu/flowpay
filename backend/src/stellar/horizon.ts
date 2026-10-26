import { Horizon, TransactionBuilder, type Asset, type Transaction, type FeeBumpTransaction } from '@stellar/stellar-sdk';
import { StellarAccountNotFoundError, StellarError, StellarSubmitTimeoutError } from '../core/errors.js';
import { getNetworkConfig } from './config.js';

/**
 * Typed Horizon access with honest error mapping. Every failure becomes a StellarError
 * subclass; nothing here ever fabricates a hash or a success.
 */

export interface SubmitResult {
  hash: string;
  ledger: number;
  successful: true;
}

export interface PathQuote {
  sourceAsset: { code: string; issuer: string | null };
  sourceAmount: string;
  destinationAmount: string;
  path: Array<{ code: string; issuer: string | null }>;
}

/** Narrow surface of Horizon.Server we depend on — lets tests inject a fake. */
export interface HorizonGateway {
  loadAccount(accountId: string): Promise<Horizon.AccountResponse>;
  submitTransaction(tx: Transaction | FeeBumpTransaction): Promise<Horizon.HorizonApi.SubmitTransactionResponse>;
  getTransaction(hash: string): Promise<{ hash: string; ledger: number; successful: boolean }>;
  strictReceivePaths(sourceAssets: Asset[], destinationAsset: Asset, destinationAmount: string): Promise<PathQuote[]>;
  strictSendPaths(sourceAsset: Asset, sourceAmount: string, destinationAssets: Asset[]): Promise<PathQuote[]>;
  fetchBaseFee(): Promise<number>;
}

const OP_CODE_MESSAGES: Record<string, string> = {
  op_underfunded: 'Insufficient balance to cover this payment.',
  op_no_trust: 'The recipient has not enabled this currency in their wallet yet.',
  op_src_no_trust: 'Your wallet has not enabled this currency yet.',
  op_no_destination: 'The recipient wallet does not exist on Stellar yet.',
  op_line_full: 'The recipient wallet cannot hold this much of the currency.',
  op_over_source_max: 'The exchange rate moved past your limit. Refresh the quote and try again.',
  op_under_dest_min: 'The exchange rate moved past your limit. Refresh the quote and try again.',
  op_too_few_offers: 'There is not enough liquidity to convert between these currencies right now.',
  op_low_reserve: 'This wallet needs more XLM to cover the Stellar minimum balance.',
  op_not_authorized: 'This currency issuer has not authorized the wallet.',
  op_no_issuer: 'The currency issuer does not exist on this network.',
};

const TX_CODE_MESSAGES: Record<string, string> = {
  tx_bad_seq: 'This transaction is out of date. Please rebuild and sign it again.',
  tx_bad_auth: 'The transaction signature is invalid for this wallet.',
  tx_insufficient_balance: 'This wallet does not have enough XLM to pay the network fee.',
  tx_insufficient_fee: 'The network is busy; the fee was too low. Please retry.',
  tx_too_late: 'The transaction expired before it was submitted. Please sign it again.',
  tx_no_source_account: 'The sending wallet does not exist on Stellar yet.',
};

type MaybeNetworkError = {
  message?: string;
  response?: { status?: number; data?: { type?: string; title?: string; detail?: string; extras?: any } };
};

/** Human-readable explanation for Horizon result codes (first meaningful one wins). */
export function describeResultCodes(codes?: { transaction?: string; operations?: string[] }): string {
  for (const op of codes?.operations ?? []) {
    if (op !== 'op_success' && OP_CODE_MESSAGES[op]) return OP_CODE_MESSAGES[op];
  }
  if (codes?.transaction && TX_CODE_MESSAGES[codes.transaction]) return TX_CODE_MESSAGES[codes.transaction];
  return `Stellar rejected the transaction (${codes?.transaction ?? 'unknown'}${
    codes?.operations?.length ? `: ${codes.operations.join(', ')}` : ''
  }).`;
}

/**
 * Maps any thrown value from a Horizon call into a StellarError. When `submittedHash` is
 * given (i.e. this was a submit), timeouts and dropped connections become
 * StellarSubmitTimeoutError — the outcome is unknown, not failed.
 */
export function mapHorizonError(err: unknown, submittedHash?: string): StellarError {
  if (err instanceof StellarError) return err;
  const e = err as MaybeNetworkError;
  const status = e?.response?.status;
  const data = e?.response?.data;
  const resultCodes = data?.extras?.result_codes as { transaction?: string; operations?: string[] } | undefined;

  if (resultCodes) {
    return new StellarError(describeResultCodes(resultCodes), 400, 'STELLAR_TX_FAILED', resultCodes, {
      resultXdr: data?.extras?.result_xdr,
    });
  }

  const isTimeout = status === 504 || /timeout/i.test(data?.type ?? '') || /timeout|ETIMEDOUT/i.test(e?.message ?? '');
  const isDropped = status === undefined && !!submittedHash;
  if (submittedHash && (isTimeout || isDropped)) {
    return new StellarSubmitTimeoutError(submittedHash, { cause: e?.message });
  }

  const message = data?.detail || data?.title || e?.message || 'Unknown Horizon error';
  return new StellarError(`Horizon request failed: ${message}`, status && status >= 400 ? status : 502, 'STELLAR_HORIZON_ERROR');
}

function isNotFound(err: unknown): boolean {
  return (err as MaybeNetworkError)?.response?.status === 404;
}

export class SdkHorizonGateway implements HorizonGateway {
  private readonly server: Horizon.Server;

  constructor(horizonUrl: string = getNetworkConfig().horizonUrl) {
    this.server = new Horizon.Server(horizonUrl, { allowHttp: horizonUrl.startsWith('http://') });
  }

  loadAccount(accountId: string) {
    return this.server.loadAccount(accountId);
  }

  submitTransaction(tx: Transaction | FeeBumpTransaction) {
    return this.server.submitTransaction(tx, { skipMemoRequiredCheck: false });
  }

  async getTransaction(hash: string) {
    const record = await this.server.transactions().transaction(hash).call();
    return { hash: record.hash, ledger: record.ledger_attr, successful: record.successful };
  }

  async strictReceivePaths(sourceAssets: Asset[], destinationAsset: Asset, destinationAmount: string): Promise<PathQuote[]> {
    const page = await this.server.strictReceivePaths(sourceAssets, destinationAsset, destinationAmount).call();
    return page.records.map((r) => ({
      sourceAsset: {
        code: r.source_asset_type === 'native' ? 'XLM' : r.source_asset_code,
        issuer: r.source_asset_type === 'native' ? null : r.source_asset_issuer,
      },
      sourceAmount: r.source_amount,
      destinationAmount: r.destination_amount,
      path: r.path.map((p) => ({
        code: p.asset_type === 'native' ? 'XLM' : p.asset_code,
        issuer: p.asset_type === 'native' ? null : p.asset_issuer,
      })),
    }));
  }

  async strictSendPaths(sourceAsset: Asset, sourceAmount: string, destinationAssets: Asset[]): Promise<PathQuote[]> {
    const page = await this.server.strictSendPaths(sourceAsset, sourceAmount, destinationAssets).call();
    return page.records.map((r) => ({
      sourceAsset: {
        code: r.source_asset_type === 'native' ? 'XLM' : r.source_asset_code,
        issuer: r.source_asset_type === 'native' ? null : r.source_asset_issuer,
      },
      sourceAmount: r.source_amount,
      destinationAmount: r.destination_amount,
      path: r.path.map((p) => ({
        code: p.asset_type === 'native' ? 'XLM' : p.asset_code,
        issuer: p.asset_type === 'native' ? null : p.asset_issuer,
      })),
    }));
  }

  fetchBaseFee() {
    return this.server.fetchBaseFee();
  }
}

export class StellarHorizon {
  constructor(private readonly gateway: HorizonGateway = new SdkHorizonGateway()) {}

  /** Loads an account; a missing account is a typed StellarAccountNotFoundError. */
  async loadAccount(accountId: string): Promise<Horizon.AccountResponse> {
    try {
      return await this.gateway.loadAccount(accountId);
    } catch (err) {
      if (isNotFound(err)) throw new StellarAccountNotFoundError(accountId);
      throw mapHorizonError(err);
    }
  }

  /** Returns null (not an error) when the account doesn't exist yet. */
  async findAccount(accountId: string): Promise<Horizon.AccountResponse | null> {
    try {
      return await this.loadAccount(accountId);
    } catch (err) {
      if (err instanceof StellarAccountNotFoundError) return null;
      throw err;
    }
  }

  /**
   * Submits a SIGNED transaction envelope. Resolves only on `successful: true` with a real
   * hash; rejects with StellarError (failed) or StellarSubmitTimeoutError (unknown outcome).
   */
  async submitSignedXdr(signedXdr: string): Promise<SubmitResult> {
    let tx: Transaction | FeeBumpTransaction;
    try {
      tx = TransactionBuilder.fromXDR(signedXdr, getNetworkConfig().passphrase);
    } catch (err) {
      throw new StellarError(`Signed transaction is not valid XDR: ${(err as Error).message}`, 400, 'STELLAR_INVALID_XDR');
    }
    if (tx.signatures.length === 0) {
      throw new StellarError('Transaction is not signed.', 400, 'STELLAR_UNSIGNED_TX');
    }
    const hash = Buffer.from(tx.hash()).toString('hex');
    try {
      const res = await this.gateway.submitTransaction(tx);
      if (!res.successful) {
        throw new StellarError('Stellar reported the transaction as unsuccessful.', 400, 'STELLAR_TX_FAILED');
      }
      return { hash: res.hash, ledger: res.ledger, successful: true };
    } catch (err) {
      throw mapHorizonError(err, hash);
    }
  }

  /**
   * Resolves a previously-ambiguous submission. Returns 'COMPLETED' / 'FAILED' when Horizon
   * knows the tx, 'PENDING' when it hasn't (yet) been seen in a ledger.
   */
  async reconcile(hash: string): Promise<{ status: 'COMPLETED' | 'FAILED' | 'PENDING'; ledger?: number }> {
    try {
      const tx = await this.gateway.getTransaction(hash);
      return { status: tx.successful ? 'COMPLETED' : 'FAILED', ledger: tx.ledger };
    } catch (err) {
      if (isNotFound(err)) return { status: 'PENDING' };
      throw mapHorizonError(err);
    }
  }

  async quoteStrictReceive(sourceAssets: Asset[], destinationAsset: Asset, destinationAmount: string): Promise<PathQuote[]> {
    try {
      return await this.gateway.strictReceivePaths(sourceAssets, destinationAsset, destinationAmount);
    } catch (err) {
      throw mapHorizonError(err);
    }
  }

  async quoteStrictSend(sourceAsset: Asset, sourceAmount: string, destinationAssets: Asset[]): Promise<PathQuote[]> {
    try {
      return await this.gateway.strictSendPaths(sourceAsset, sourceAmount, destinationAssets);
    } catch (err) {
      throw mapHorizonError(err);
    }
  }

  async baseFee(): Promise<number> {
    try {
      return await this.gateway.fetchBaseFee();
    } catch (err) {
      throw mapHorizonError(err);
    }
  }
}

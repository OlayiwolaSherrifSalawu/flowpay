import {
  Account,
  Address,
  Contract,
  Keypair,
  TransactionBuilder,
  nativeToScVal,
  rpc,
  scValToNative,
  xdr,
  type Transaction,
} from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { StellarError, StellarSubmitTimeoutError } from '../core/errors.js';
import { assetFor, getNetworkConfig } from './config.js';

/**
 * Soroban access for FlowPay's PayrollVault contract (contracts/payroll_vault).
 *
 * Same money-safety rules as the classic layer: a transaction is COMPLETED only
 * when the RPC reports SUCCESS for its real hash; a submit that we can't confirm in
 * time is PENDING (reconcile by hash), and every failure surfaces as a failure.
 */

export const STROOPS_PER_CENT = 100_000n; // 7-decimal Stellar amounts; cents have 2.

export interface SendResult {
  status: 'PENDING' | 'DUPLICATE' | 'TRY_AGAIN_LATER' | 'ERROR';
  hash: string;
  errorDetail?: string;
}

export interface TxStatus {
  status: 'SUCCESS' | 'FAILED' | 'NOT_FOUND';
  returnValue?: xdr.ScVal;
  errorDetail?: string;
}

/** Injectable RPC boundary (real server in production, fakes in tests). */
export interface SorobanGateway {
  loadAccount(accountId: string): Promise<Account>;
  /** Simulates and assembles (footprint, resource fees, auth). Throws on simulation errors. */
  prepare(tx: Transaction): Promise<Transaction>;
  /** Read-only call: simulate and return the result value. */
  read(tx: Transaction): Promise<xdr.ScVal>;
  send(tx: Transaction): Promise<SendResult>;
  getStatus(hash: string): Promise<TxStatus>;
}

export class RpcSorobanGateway implements SorobanGateway {
  private readonly server: rpc.Server;
  constructor(url = env.SOROBAN_RPC_URL ?? 'https://soroban-testnet.stellar.org') {
    this.server = new rpc.Server(url, { allowHttp: url.startsWith('http://') });
  }

  loadAccount(accountId: string): Promise<Account> {
    return this.server.getAccount(accountId);
  }

  async prepare(tx: Transaction): Promise<Transaction> {
    try {
      return (await this.server.prepareTransaction(tx)) as Transaction;
    } catch (err) {
      throw new StellarError(`The contract rejected this request: ${simplifyContractError(err)}`, 400, 'SOROBAN_SIMULATION_FAILED');
    }
  }

  async read(tx: Transaction): Promise<xdr.ScVal> {
    const sim = await this.server.simulateTransaction(tx);
    if (rpc.Api.isSimulationError(sim)) {
      throw new StellarError(`The contract rejected this request: ${simplifyContractError(sim.error)}`, 400, 'SOROBAN_SIMULATION_FAILED');
    }
    const retval = (sim as rpc.Api.SimulateTransactionSuccessResponse).result?.retval;
    if (!retval) throw new StellarError('The contract returned no value.', 502, 'SOROBAN_NO_RESULT');
    return retval;
  }

  async send(tx: Transaction): Promise<SendResult> {
    const res = await this.server.sendTransaction(tx);
    return {
      status: res.status,
      hash: res.hash,
      errorDetail: resultCode(res.errorResult),
    };
  }

  async getStatus(hash: string): Promise<TxStatus> {
    const res = await this.server.getTransaction(hash);
    if (res.status === rpc.Api.GetTransactionStatus.SUCCESS) return { status: 'SUCCESS', returnValue: res.returnValue };
    if (res.status === rpc.Api.GetTransactionStatus.FAILED) {
      return { status: 'FAILED', errorDetail: resultCode(res.resultXdr) };
    }
    return { status: 'NOT_FOUND' };
  }
}

/** Result code of a TransactionResult (e.g. "txFailed"), without depending on XDR internals. */
function resultCode(result: unknown): string | undefined {
  const r = (result as { result?: { type?: unknown } } | undefined)?.result;
  return r?.type !== undefined ? String(r.type) : undefined;
}

/** Contract panics arrive as "Error(Contract, #7)"; map our codes to plain language. */
const CONTRACT_ERRORS: Record<number, string> = {
  1: 'the payroll has no employees',
  2: 'too many employees for one guarantee (max 100)',
  3: 'every salary must be more than zero',
  4: 'an employee appears twice',
  5: 'payday must be in the future',
  6: 'that guarantee does not exist',
  7: "it isn't payday yet",
  8: 'there is nothing left to pay for this person',
  9: 'unclaimed salaries can only be reclaimed 30 days after payday',
  10: 'the payroll total is too large',
};

export function simplifyContractError(err: unknown): string {
  const text = typeof err === 'string' ? err : (err as Error)?.message ?? String(err);
  const m = /Error\(Contract, #(\d+)\)/.exec(text);
  if (m && CONTRACT_ERRORS[Number(m[1])]) return CONTRACT_ERRORS[Number(m[1])];
  if (/balance|insufficient|resulting balance/i.test(text)) return 'not enough USD in the paying account';
  if (/trustline/i.test(text)) return 'an account is missing the USD trustline';
  return text.split('\n')[0].slice(0, 200);
}

export interface VaultPayroll {
  employer: string;
  token: string;
  unlockAt: number;
  reclaimAfter: number;
  totalStroops: bigint;
  remainingStroops: bigint;
  employees: string[];
}

export interface SubmittedCall {
  status: 'COMPLETED';
  hash: string;
  returnValue: unknown;
}

const TX_TIMEOUT_SECONDS = 300;

export class PayrollVaultClient {
  constructor(
    private readonly gateway: SorobanGateway = new RpcSorobanGateway(),
    private readonly contractId: string | undefined = env.STELLAR_PAYROLL_VAULT_ID,
    private readonly pollMs = 1500,
    private readonly maxPolls = 20
  ) {}

  get isConfigured(): boolean {
    return !!this.contractId;
  }

  private contract(): Contract {
    if (!this.contractId) {
      throw new StellarError('The payday guarantee contract is not deployed on this server yet.', 503, 'SOROBAN_NOT_CONFIGURED');
    }
    return new Contract(this.contractId);
  }

  /** The Stellar Asset Contract for FlowPay USD — the token the vault holds. */
  static usdTokenId(): string {
    return assetFor('USD').contractId(getNetworkConfig().passphrase);
  }

  private async build(sourceAccountId: string, method: string, args: xdr.ScVal[]): Promise<Transaction> {
    const source = await this.gateway.loadAccount(sourceAccountId);
    return new TransactionBuilder(source, { fee: '10000', networkPassphrase: getNetworkConfig().passphrase })
      .addOperation(this.contract().call(method, ...args))
      .setTimeout(TX_TIMEOUT_SECONDS)
      .build();
  }

  private static unsigned(tx: Transaction): { xdr: string; hash: string; expiresAt: string } {
    const maxTime = Number(tx.timeBounds?.maxTime ?? 0);
    return {
      xdr: tx.toXDR(),
      hash: Buffer.from(tx.hash()).toString('hex'),
      expiresAt: new Date((maxTime || Math.floor(Date.now() / 1000) + TX_TIMEOUT_SECONDS) * 1000).toISOString(),
    };
  }

  /** Unsigned, simulated `fund` transaction for the employer's device to sign. */
  async buildFund(args: { employer: string; unlockAt: number; entries: Array<{ account: string; amountCents: bigint }> }) {
    const entries = xdr.ScVal.scvVec(
      args.entries.map((e) =>
        xdr.ScVal.scvVec([new Address(e.account).toScVal(), nativeToScVal(e.amountCents * STROOPS_PER_CENT, { type: 'i128' })])
      )
    );
    const tx = await this.build(args.employer, 'fund', [
      new Address(args.employer).toScVal(),
      new Address(PayrollVaultClient.usdTokenId()).toScVal(),
      nativeToScVal(args.unlockAt, { type: 'u64' }),
      entries,
    ]);
    return PayrollVaultClient.unsigned(await this.gateway.prepare(tx));
  }

  /** Unsigned, simulated `claim` transaction for the employee's device to sign. */
  async buildClaim(args: { employee: string; payrollId: number }) {
    const tx = await this.build(args.employee, 'claim', [
      nativeToScVal(args.payrollId, { type: 'u64' }),
      new Address(args.employee).toScVal(),
    ]);
    return PayrollVaultClient.unsigned(await this.gateway.prepare(tx));
  }

  /**
   * Server-side `release`: pushes an unlocked salary to its employee. Needs no user
   * signature (the contract only ever pays the recorded employee); FlowPay's
   * distributor account just pays the network fee.
   */
  async release(args: { payrollId: number; employee: string }): Promise<SubmittedCall> {
    if (!env.STELLAR_DISTRIBUTOR_SECRET) {
      throw new StellarError('Payday release is not configured on this server.', 503, 'SOROBAN_NOT_CONFIGURED');
    }
    const feePayer = Keypair.fromSecret(env.STELLAR_DISTRIBUTOR_SECRET);
    const tx = await this.gateway.prepare(
      await this.build(feePayer.publicKey(), 'release', [nativeToScVal(args.payrollId, { type: 'u64' }), new Address(args.employee).toScVal()])
    );
    tx.sign(feePayer);
    return this.submit(tx.toXDR());
  }

  /** Submits a signed envelope and waits for the ledger. COMPLETED only on SUCCESS. */
  async submit(signedXdr: string): Promise<SubmittedCall> {
    const tx = TransactionBuilder.fromXDR(signedXdr, getNetworkConfig().passphrase) as Transaction;
    const sent = await this.gateway.send(tx);
    if (sent.status === 'ERROR') {
      throw new StellarError(`The network rejected the transaction (${sent.errorDetail ?? 'unknown error'}).`, 400, 'STELLAR_TX_FAILED');
    }
    if (sent.status === 'TRY_AGAIN_LATER') {
      throw new StellarError('The network is busy. Nothing was sent; please try again.', 503, 'STELLAR_TRY_AGAIN');
    }
    for (let i = 0; i < this.maxPolls; i++) {
      const st = await this.gateway.getStatus(sent.hash);
      if (st.status === 'SUCCESS') {
        return { status: 'COMPLETED', hash: sent.hash, returnValue: st.returnValue ? scValToNative(st.returnValue) : null };
      }
      if (st.status === 'FAILED') {
        throw new StellarError(`The transaction failed on-chain (${st.errorDetail ?? 'contract error'}).`, 400, 'STELLAR_TX_FAILED');
      }
      if (this.pollMs > 0) await new Promise((r) => setTimeout(r, this.pollMs));
    }
    throw new StellarSubmitTimeoutError(sent.hash);
  }

  /** Ledger state of one guarantee. */
  async getPayroll(payrollId: number): Promise<VaultPayroll> {
    const v = scValToNative(await this.readCall('payroll', [nativeToScVal(payrollId, { type: 'u64' })])) as Record<string, unknown>;
    return {
      employer: String(v.employer),
      token: String(v.token),
      unlockAt: Number(v.unlock_at),
      reclaimAfter: Number(v.reclaim_after),
      totalStroops: BigInt(v.total as bigint),
      remainingStroops: BigInt(v.remaining as bigint),
      // `salaries` (employee → unpaid amount) decodes to a Map or a plain object.
      employees: v.salaries instanceof Map ? [...v.salaries.keys()].map(String) : Object.keys((v.salaries ?? {}) as object),
    };
  }

  /** Unpaid salary still reserved for `employee` (0 once paid). */
  async salaryStroops(payrollId: number, employee: string): Promise<bigint> {
    return BigInt(
      scValToNative(await this.readCall('salary', [nativeToScVal(payrollId, { type: 'u64' }), new Address(employee).toScVal()])) as bigint
    );
  }

  private async readCall(method: string, args: xdr.ScVal[]): Promise<xdr.ScVal> {
    // Reads need a source account for simulation only; nothing is signed or sent.
    const reader = env.STELLAR_ASSET_ISSUER ?? Keypair.random().publicKey();
    const source = env.STELLAR_ASSET_ISSUER ? await this.gateway.loadAccount(reader) : new Account(reader, '0');
    const tx = new TransactionBuilder(source, { fee: '100', networkPassphrase: getNetworkConfig().passphrase })
      .addOperation(this.contract().call(method, ...args))
      .setTimeout(TX_TIMEOUT_SECONDS)
      .build();
    return this.gateway.read(tx);
  }
}

export function stroopsToUsd(stroops: bigint): string {
  const cents = stroops / STROOPS_PER_CENT;
  return `${cents / 100n}.${String(cents % 100n).padStart(2, '0')}`;
}

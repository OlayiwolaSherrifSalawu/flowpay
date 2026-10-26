import { randomUUID } from 'node:crypto';
import { FlowPayError, InsufficientFundsError, InvalidRequestError, NotFoundError, StellarError, StellarSubmitTimeoutError } from '../../core/errors.js';
import { Money } from '../../core/money.js';
import { isPostgresDb, prisma } from '../../db/index.js';
import { StellarAccountService, summarizeAccount } from '../../stellar/accounts.js';
import { MAX_OPS_PER_TX, type BatchLegInput } from '../../stellar/batch.js';
import { explorerTxUrl, type StellarCurrency } from '../../stellar/config.js';
import { accountForUser } from '../../stellar/directory.js';
import { StellarHorizon } from '../../stellar/horizon.js';
import { recordActivity } from '../activity/record.js';
import { EmployeeService, type EmployeeRecord } from '../employees/service.js';
import { BatchPaymentService } from '../payments/batch_service.js';

/**
 * "One employer, many countries, one bill" on Stellar.
 *
 * Preview = the actual transactions: every READY employee becomes a leg paid from the
 * employer's USD (path payment into their local currency). Up to 100 employees settle
 * in ONE atomic transaction; bigger teams are split into several, each atomic.
 * Employees who can't be paid right now are listed with the reason and left out.
 */

export const PAYROLL_FUNDING_CURRENCY: StellarCurrency = 'USD';
/** Employees paid within this window are skipped unless the employer opts in. */
export const PAY_PERIOD_GUARD_DAYS = 25;

export type PayrollItemStatus = 'PENDING' | 'SUCCESS' | 'FAILED' | 'SKIPPED';
export type PayrollRunStatus = 'PREVIEW' | 'PROCESSING' | 'PENDING' | 'COMPLETED' | 'PARTIALLY_COMPLETED' | 'FAILED';

export interface PayrollRunItem {
  employeeId: string;
  name: string;
  country: string;
  targetCurrency: string;
  destinationAccount: string | null;
  targetAmountMinor: string;
  targetAmountFormatted: string;
  /** Quoted USD cost (exact for USD employees). */
  usdAmountMinor: string;
  usdAmountFormatted: string;
  exchangeRate: number;
  isRailActive: boolean;
  railValidationMessage: string;
  status: PayrollItemStatus;
  proposalId?: string;
  transactionHash?: string;
  explorerUrl?: string;
  error?: string;
}

export interface PayrollBatch {
  proposalId: string;
  signPayload?: string;
  expiresAt: string;
  employeeIds: string[];
  maxUsd: string;
  status: 'PENDING_SIGNATURE' | 'COMPLETED' | 'PENDING' | 'FAILED';
  transactionHash?: string;
  explorerUrl?: string;
  error?: string;
}

export interface PayrollRun {
  runId: string;
  employerUserId: string;
  title: string;
  fundingCurrency: StellarCurrency;
  totalUsdMinor: string;
  totalUsdFormatted: string;
  /** Worst-case USD spend signed into the transactions (quotes + slippage cap). */
  maxUsdFormatted: string;
  /** Stellar network fees, paid in XLM by the employer account. */
  networkFeeXlm: string;
  employerBalanceUsdFormatted: string;
  isBalanceSufficient: boolean;
  employeeCount: number;
  payableCount: number;
  countries: string[];
  currencies: string[];
  allRailsActive: boolean;
  items: PayrollRunItem[];
  batches: PayrollBatch[];
  status: PayrollRunStatus;
  createdAt: string;
  executedAt?: string;
}

const runs = new Map<string, PayrollRun>();
let horizon = new StellarHorizon();

export function setPayrollHorizonForTests(h: StellarHorizon): void {
  horizon = h;
  runs.clear();
}

function skipReason(e: EmployeeRecord): string | null {
  if (e.status === 'SUSPENDED') return 'Suspended from payroll';
  if (e.status !== 'READY' || !e.walletAddress) return 'Has not accepted the invitation yet';
  return null;
}

/** Strips signing payloads from runs returned after preview. */
function publicRun(run: PayrollRun): PayrollRun {
  return { ...run, batches: run.batches.map(({ signPayload: _x, ...b }) => b) };
}

export class PayrollOrchestrationService {
  /** employeeId → when they were last paid (successful runs only) by this employer. */
  private static async lastPaidAt(employerUserId: string): Promise<Map<string, string>> {
    const paid = new Map<string, string>();
    const note = (id: string, at: string) => {
      if (!paid.has(id) || paid.get(id)! < at) paid.set(id, at);
    };
    for (const r of runs.values()) {
      if (r.employerUserId !== employerUserId || !r.executedAt) continue;
      for (const i of r.items) if (i.status === 'SUCCESS') note(i.employeeId, r.executedAt);
    }
    if (isPostgresDb()) {
      try {
        const rows = await prisma.payrollItem.findMany({
          where: { status: 'SUCCESS', payrollRun: { employerUserId } },
          select: { employeeId: true, payrollRun: { select: { executedAt: true } } },
        });
        for (const r of rows) note(r.employeeId, r.payrollRun.executedAt.toISOString());
      } catch (err: any) {
        console.warn('[Payroll] could not read payment history:', err.message);
      }
    }
    return paid;
  }

  static async getPreview(employerUserId: string, opts: { includeRecentlyPaid?: boolean } = {}): Promise<PayrollRun> {
    const employerAccount = await accountForUser(employerUserId);
    if (!employerAccount) throw new InvalidRequestError('Set up and activate your business wallet before running payroll.');
    const accounts = new StellarAccountService(horizon);
    const employerSummary = await accounts.getSummary(employerAccount);
    const usdBalance = employerSummary.balances.find((b) => b.currency === PAYROLL_FUNDING_CURRENCY)?.balance ?? Money.zero('USD');

    const employees = await EmployeeService.listEmployees(employerUserId);
    const lastPaid = opts.includeRecentlyPaid ? new Map<string, string>() : await this.lastPaidAt(employerUserId);
    const guardSince = new Date(Date.now() - PAY_PERIOD_GUARD_DAYS * 86_400_000).toISOString();
    const runId = `payroll_${randomUUID()}`;
    const items: PayrollRunItem[] = [];
    const payable: Array<{ e: EmployeeRecord; item: PayrollRunItem }> = [];

    for (const e of employees) {
      const target = Money.fromMinor(e.payrollAmountMinor, e.targetCurrency as StellarCurrency);
      const item: PayrollRunItem = {
        employeeId: e.id,
        name: `${e.firstName} ${e.lastName}`,
        country: e.country,
        targetCurrency: e.targetCurrency,
        destinationAccount: e.walletAddress,
        targetAmountMinor: target.amountMinor.toString(),
        targetAmountFormatted: target.toMajorString(),
        usdAmountMinor: '0',
        usdAmountFormatted: '0.00',
        exchangeRate: 0,
        isRailActive: false,
        railValidationMessage: '',
        status: 'SKIPPED',
      };
      let reason = skipReason(e);
      const paidAt = lastPaid.get(e.id);
      if (!reason && paidAt && paidAt > guardSince) reason = `Already paid on ${paidAt.slice(0, 10)} (this pay period)`;
      if (!reason) {
        const acct = await horizon.findAccount(e.walletAddress!);
        const s = summarizeAccount(e.walletAddress!, acct);
        if (!s.exists) reason = 'Wallet is not active on Stellar';
        else if (s.missingTrustlines.includes(e.targetCurrency as StellarCurrency)) reason = `Wallet has not enabled ${e.targetCurrency}`;
      }
      if (reason) {
        item.railValidationMessage = reason;
      } else {
        item.isRailActive = true;
        item.railValidationMessage = `Ready — paid in ${e.targetCurrency} on Stellar`;
        item.status = 'PENDING';
        payable.push({ e, item });
      }
      items.push(item);
    }

    const run: PayrollRun = {
      runId,
      employerUserId,
      title: `Payroll — ${new Date().toISOString().slice(0, 10)}`,
      fundingCurrency: PAYROLL_FUNDING_CURRENCY,
      totalUsdMinor: '0',
      totalUsdFormatted: '0.00',
      maxUsdFormatted: '0.00',
      networkFeeXlm: '0',
      employerBalanceUsdFormatted: usdBalance.toMajorString(),
      isBalanceSufficient: true,
      employeeCount: employees.length,
      payableCount: payable.length,
      countries: [...new Set(employees.map((e) => e.country))],
      currencies: [...new Set(employees.map((e) => e.targetCurrency))],
      allRailsActive: items.every((i) => i.isRailActive),
      items,
      batches: [],
      status: 'PREVIEW',
      createdAt: new Date().toISOString(),
    };

    let totalUsd = Money.zero('USD');
    let maxUsd = Money.zero('USD');
    for (let i = 0; i < payable.length; i += MAX_OPS_PER_TX) {
      const chunk = payable.slice(i, i + MAX_OPS_PER_TX);
      const legs: BatchLegInput[] = chunk.map(({ e, item }) => ({
        label: item.name,
        to: e.walletAddress!,
        mode: 'exact_receive',
        amount: { amountMinor: item.targetAmountMinor, currency: e.targetCurrency },
        fundingCurrency: PAYROLL_FUNDING_CURRENCY,
      }));
      let proposal;
      try {
        proposal = await BatchPaymentService.propose({ userId: employerUserId, legs, memo: 'FlowPay payroll', context: { purpose: 'PAYROLL', reference: runId } });
      } catch (err) {
        if (err instanceof InsufficientFundsError) {
          run.isBalanceSufficient = false;
          break;
        }
        throw err;
      }
      proposal.legs.forEach((leg: any, idx: number) => {
        const item = chunk[idx].item;
        item.usdAmountMinor = leg.sourceAmountMinor;
        item.usdAmountFormatted = leg.sourceAmount;
        item.exchangeRate = Number(leg.destAmount) / Number(leg.sourceAmount);
        item.proposalId = proposal.proposalId;
        totalUsd = totalUsd.add(Money.fromMinor(leg.sourceAmountMinor, 'USD'));
      });
      const chunkMax = Money.fromMajor(proposal.maxTotals.USD ?? '0', 'USD');
      maxUsd = maxUsd.add(chunkMax);
      run.batches.push({
        proposalId: proposal.proposalId,
        signPayload: proposal.signPayload,
        expiresAt: proposal.expiresAt,
        employeeIds: chunk.map((c) => c.e.id),
        maxUsd: chunkMax.toMajorString(),
        status: 'PENDING_SIGNATURE',
      });
    }

    if (maxUsd.isGreaterThan(usdBalance)) run.isBalanceSufficient = false;
    if (!run.isBalanceSufficient) run.batches = []; // nothing to sign if it can't be covered
    run.totalUsdMinor = totalUsd.amountMinor.toString();
    run.totalUsdFormatted = totalUsd.toMajorString();
    run.maxUsdFormatted = maxUsd.toMajorString();
    run.networkFeeXlm = ((payable.length * 100) / 1e7).toFixed(7); // 100 stroops per operation
    runs.set(runId, run);
    return run;
  }

  /**
   * Submits each signed batch. Every batch is atomic; batches are independent. The run
   * is COMPLETED only if every batch settled.
   */
  static async executePayroll(employerUserId: string, runId: string, signed: Record<string, string>): Promise<PayrollRun> {
    const run = runs.get(runId);
    if (!run || run.employerUserId !== employerUserId) throw new NotFoundError('Payroll run not found. Please preview payroll again.');
    if (run.status !== 'PREVIEW') throw new InvalidRequestError('This payroll run was already submitted.');
    if (run.batches.length === 0) throw new InvalidRequestError(run.isBalanceSufficient ? 'Nobody is ready to be paid.' : 'Your USD balance does not cover this payroll.');
    for (const b of run.batches) {
      if (typeof signed?.[b.proposalId] !== 'string') throw new InvalidRequestError('Every payroll batch must be signed.');
    }

    run.status = 'PROCESSING';
    const byEmployee = new Map(run.items.map((i) => [i.employeeId, i]));
    for (const batch of run.batches) {
      try {
        const res = await BatchPaymentService.execute({ userId: employerUserId, proposalId: batch.proposalId, signedXdr: signed[batch.proposalId] });
        batch.status = 'COMPLETED';
        batch.transactionHash = res.transactionHash;
        batch.explorerUrl = res.explorerUrl;
        for (const id of batch.employeeIds) Object.assign(byEmployee.get(id)!, { status: 'SUCCESS', transactionHash: res.transactionHash, explorerUrl: res.explorerUrl });
      } catch (err) {
        const pending = err instanceof StellarSubmitTimeoutError;
        batch.status = pending ? 'PENDING' : 'FAILED';
        batch.error = (err as Error).message;
        if (pending) batch.transactionHash = (err as StellarSubmitTimeoutError).hash;
        for (const id of batch.employeeIds) {
          Object.assign(byEmployee.get(id)!, {
            status: pending ? 'PENDING' : 'FAILED',
            transactionHash: pending ? batch.transactionHash : undefined,
            explorerUrl: pending ? explorerTxUrl(batch.transactionHash!) : undefined,
            error: pending ? 'Waiting for network confirmation' : (err as Error).message,
          });
        }
        if (!(err instanceof StellarError) && !(err instanceof FlowPayError)) console.error('[Payroll] unexpected batch error:', err);
      }
      delete batch.signPayload;
    }

    const statuses = run.batches.map((b) => b.status);
    run.status = statuses.every((s) => s === 'COMPLETED')
      ? 'COMPLETED'
      : statuses.some((s) => s === 'PENDING')
        ? 'PENDING'
        : statuses.some((s) => s === 'COMPLETED')
          ? 'PARTIALLY_COMPLETED'
          : 'FAILED';
    run.executedAt = new Date().toISOString();

    await this.persist(run);
    await recordActivity({
      category: 'BUSINESS',
      action: run.status === 'FAILED' ? 'PAYROLL_FAILED' : 'PAYROLL_EXECUTED',
      actor: employerUserId,
      details: {
        runId,
        status: run.status,
        totalUsd: run.totalUsdFormatted,
        paid: run.items.filter((i) => i.status === 'SUCCESS').length,
        transactionHashes: run.batches.map((b) => b.transactionHash).filter(Boolean),
      },
    });
    return publicRun(run);
  }

  private static async persist(run: PayrollRun): Promise<void> {
    if (!isPostgresDb()) return;
    try {
      await prisma.payrollRun.create({
        data: {
          id: run.runId,
          employerUserId: run.employerUserId,
          title: run.title,
          totalUsdMinor: Number(run.totalUsdMinor),
          feeUsdMinor: 0,
          employeeCount: run.payableCount,
          status: run.status,
          reference: run.batches[0]?.transactionHash ?? null,
          executedAt: new Date(run.executedAt!),
          items: {
            create: run.items
              .filter((i) => i.status !== 'SKIPPED')
              .map((i) => ({
                id: `pi_${randomUUID()}`,
                employeeId: i.employeeId,
                employeeName: i.name,
                country: i.country,
                targetCurrency: i.targetCurrency,
                targetAmountMinor: Number(i.targetAmountMinor),
                usdAmountMinor: Number(i.usdAmountMinor),
                exchangeRate: i.exchangeRate,
                status: i.status,
                proposalId: i.proposalId ?? null,
                transactionHash: i.transactionHash ?? null,
                errorReason: i.error ?? null,
              })),
          },
        },
      });
    } catch (err: any) {
      console.warn('[Payroll] run persistence failed:', err.message);
    }
  }

  static async listRuns(employerUserId: string): Promise<PayrollRun[]> {
    return [...runs.values()]
      .filter((r) => r.employerUserId === employerUserId && r.status !== 'PREVIEW')
      .sort((a, b) => (b.executedAt ?? '').localeCompare(a.executedAt ?? ''))
      .map(publicRun);
  }

  static async getRun(employerUserId: string, runId: string): Promise<PayrollRun> {
    const run = runs.get(runId);
    if (!run || run.employerUserId !== employerUserId) throw new NotFoundError('Payroll run not found.');
    return publicRun(run);
  }
}

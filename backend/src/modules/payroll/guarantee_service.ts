import { InvalidRequestError, NotFoundError, StellarSubmitTimeoutError } from '../../core/errors.js';
import { explorerTxUrl } from '../../stellar/config.js';
import { accountForUser } from '../../stellar/directory.js';
import { ProposalStore, assertSignedMatches } from '../../stellar/proposals.js';
import { PayrollVaultClient, STROOPS_PER_CENT, stroopsToUsd } from '../../stellar/soroban.js';
import { recordActivity } from '../activity/record.js';
import { PayrollOrchestrationService } from './service.js';

/**
 * Payday guarantee on Soroban (contracts/payroll_vault).
 *
 * The employer locks next payday's payroll — each employee's quoted USD cost — in
 * the PayrollVault contract. Employees can verify on-chain that their pay is
 * reserved and when it unlocks; from payday it is released to them (by FlowPay,
 * or claimed by the employee). The employer can't take it back before then.
 */

export interface GuaranteeEntry {
  employeeId: string;
  name: string;
  account: string;
  amountUsd: string;
  /** e.g. "150,000.00 NGN": what the reserved USD covered at quote time. */
  coversFormatted: string;
}

export interface Guarantee {
  payrollId: number;
  employerUserId: string;
  employerAccount: string;
  unlockAt: string;
  reclaimAfter: string;
  totalUsd: string;
  entries: GuaranteeEntry[];
  fundingTxHash: string;
  explorerUrl: string;
  createdAt: string;
}

export interface GuaranteeStatus extends Guarantee {
  remainingUsd: string;
  isUnlocked: boolean;
  entries: Array<GuaranteeEntry & { paid: boolean }>;
}

interface FundMeta {
  employerAccount: string;
  unlockAt: number;
  entries: GuaranteeEntry[];
}

interface ClaimMeta {
  payrollId: number;
  account: string;
}

const MIN_LEAD_SECONDS = 60;
const MAX_LEAD_SECONDS = 90 * 24 * 60 * 60;

const guarantees = new Map<number, Guarantee>();
const fundProposals = new ProposalStore<FundMeta>();
const claimProposals = new ProposalStore<ClaimMeta>();
let vault = new PayrollVaultClient();

export function setGuaranteeVaultForTests(client: PayrollVaultClient): void {
  vault = client;
  guarantees.clear();
  fundProposals.clear();
  claimProposals.clear();
}

async function requireAccount(userId: string): Promise<string> {
  const account = await accountForUser(userId);
  if (!account) throw new InvalidRequestError('Set up your wallet first.');
  return account;
}

function parseUnlock(unlockAt: unknown): number {
  const ms = typeof unlockAt === 'string' ? Date.parse(unlockAt) : NaN;
  if (!Number.isFinite(ms)) throw new InvalidRequestError('unlockAt must be an ISO date-time.');
  const secs = Math.floor(ms / 1000);
  const lead = secs - Math.floor(Date.now() / 1000);
  if (lead < MIN_LEAD_SECONDS) throw new InvalidRequestError('Payday must be at least a minute from now.');
  if (lead > MAX_LEAD_SECONDS) throw new InvalidRequestError('Payday can be at most 90 days ahead.');
  return secs;
}

function usdToCents(usd: string): bigint {
  const [whole, frac = ''] = usd.split('.');
  return BigInt(whole) * 100n + BigInt((frac + '00').slice(0, 2));
}

export class PayrollGuaranteeService {
  /** Builds the `fund` transaction from the live payroll preview. Nothing moves until signed. */
  static async propose(employerUserId: string, body: { unlockAt?: unknown }) {
    const unlockAt = parseUnlock(body.unlockAt);
    const employerAccount = await requireAccount(employerUserId);
    // A guarantee is for the NEXT payday, so recent payments don't exclude anyone.
    const preview = await PayrollOrchestrationService.getPreview(employerUserId, { includeRecentlyPaid: true });
    const payable = preview.items.filter((i) => i.status === 'PENDING' && i.destinationAccount);
    if (payable.length === 0) throw new InvalidRequestError('No employees can be paid yet. Invite your team first.');

    const entries: GuaranteeEntry[] = payable.map((i) => ({
      employeeId: i.employeeId,
      name: i.name,
      account: i.destinationAccount!,
      amountUsd: (Number(i.usdAmountMinor) / 100).toFixed(2),
      coversFormatted: `${Number(i.targetAmountFormatted).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${i.targetCurrency}`,
    }));
    const tx = await vault.buildFund({
      employer: employerAccount,
      unlockAt,
      entries: entries.map((e) => ({ account: e.account, amountCents: usdToCents(e.amountUsd) })),
    });
    fundProposals.put(tx.hash, employerUserId, tx.expiresAt, { employerAccount, unlockAt, entries });
    const totalCents = entries.reduce((sum, e) => sum + usdToCents(e.amountUsd), 0n);
    return {
      proposalId: tx.hash,
      signPayload: tx.xdr,
      expiresAt: tx.expiresAt,
      unlockAt: new Date(unlockAt * 1000).toISOString(),
      totalUsd: stroopsToUsd(totalCents * STROOPS_PER_CENT),
      entries,
      skipped: preview.items.filter((i) => i.status === 'SKIPPED').map((i) => ({ name: i.name, reason: i.error ?? i.railValidationMessage })),
    };
  }

  /** Submits the employer-signed `fund`. Recorded only after the ledger confirms it. */
  static async execute(employerUserId: string, proposalId: string, signedXdr: string): Promise<Guarantee> {
    const proposal = fundProposals.take(proposalId, employerUserId);
    assertSignedMatches(proposalId, signedXdr);
    fundProposals.consume(proposalId);
    const result = await vault.submit(signedXdr); // throws FAILED / PENDING honestly
    const payrollId = Number(result.returnValue);
    if (!Number.isSafeInteger(payrollId) || payrollId <= 0) {
      throw new InvalidRequestError(`Funded in ${result.hash}, but the contract returned no guarantee id.`);
    }
    const { employerAccount, unlockAt, entries } = proposal.meta;
    const totalCents = entries.reduce((sum, e) => sum + usdToCents(e.amountUsd), 0n);
    const g: Guarantee = {
      payrollId,
      employerUserId,
      employerAccount,
      unlockAt: new Date(unlockAt * 1000).toISOString(),
      reclaimAfter: new Date((unlockAt + 30 * 24 * 3600) * 1000).toISOString(),
      totalUsd: stroopsToUsd(totalCents * STROOPS_PER_CENT),
      entries,
      fundingTxHash: result.hash,
      explorerUrl: explorerTxUrl(result.hash),
      createdAt: new Date().toISOString(),
    };
    guarantees.set(payrollId, g);
    await recordActivity({
      category: 'BUSINESS',
      action: 'PAYROLL_GUARANTEED',
      actor: employerUserId,
      details: { payrollId, totalUsd: g.totalUsd, employees: entries.length, unlockAt: g.unlockAt, transactionHash: result.hash },
    }).catch(() => undefined);
    return g;
  }

  /** Chain state for one guarantee: what's still reserved, and for whom. */
  static async status(g: Guarantee): Promise<GuaranteeStatus> {
    const onChain = await vault.getPayroll(g.payrollId);
    const entries = await Promise.all(
      g.entries.map(async (e) => ({ ...e, paid: (await vault.salaryStroops(g.payrollId, e.account)) === 0n }))
    );
    return {
      ...g,
      remainingUsd: stroopsToUsd(onChain.remainingStroops),
      isUnlocked: Date.now() / 1000 >= onChain.unlockAt,
      entries,
    };
  }

  static async listForEmployer(employerUserId: string): Promise<GuaranteeStatus[]> {
    const mine = [...guarantees.values()].filter((g) => g.employerUserId === employerUserId);
    return Promise.all(mine.map((g) => this.status(g)));
  }

  /** Guarantees that reserve pay for the signed-in employee. */
  static async listForEmployee(userId: string) {
    const account = await accountForUser(userId);
    if (!account) return [];
    const out = [];
    for (const g of guarantees.values()) {
      const entry = g.entries.find((e) => e.account === account);
      if (!entry) continue;
      const remaining = await vault.salaryStroops(g.payrollId, account);
      out.push({
        payrollId: g.payrollId,
        unlockAt: g.unlockAt,
        amountUsd: entry.amountUsd,
        coversFormatted: entry.coversFormatted,
        paid: remaining === 0n,
        isUnlocked: Date.now() >= Date.parse(g.unlockAt),
        explorerUrl: g.explorerUrl,
      });
    }
    return out;
  }

  /** Employer (or FlowPay) pushes every unlocked, unpaid salary to its employee. */
  static async releaseAll(employerUserId: string, payrollId: number) {
    const g = guarantees.get(payrollId);
    if (!g || g.employerUserId !== employerUserId) throw new NotFoundError('Guarantee not found.');
    if (Date.now() < Date.parse(g.unlockAt)) throw new InvalidRequestError("It isn't payday yet.");
    const results = [];
    for (const e of g.entries) {
      if ((await vault.salaryStroops(payrollId, e.account)) === 0n) {
        results.push({ employeeId: e.employeeId, name: e.name, status: 'ALREADY_PAID' as const });
        continue;
      }
      try {
        const r = await vault.release({ payrollId, employee: e.account });
        results.push({ employeeId: e.employeeId, name: e.name, status: 'COMPLETED' as const, hash: r.hash, explorerUrl: explorerTxUrl(r.hash) });
      } catch (err) {
        const pending = err instanceof StellarSubmitTimeoutError;
        results.push({
          employeeId: e.employeeId,
          name: e.name,
          status: pending ? ('PENDING' as const) : ('FAILED' as const),
          hash: pending ? err.hash : undefined,
          error: (err as Error).message,
        });
      }
    }
    return { payrollId, results };
  }

  static async proposeClaim(userId: string, payrollId: number) {
    const account = await requireAccount(userId);
    const tx = await vault.buildClaim({ employee: account, payrollId });
    claimProposals.put(tx.hash, userId, tx.expiresAt, { payrollId, account });
    return { proposalId: tx.hash, signPayload: tx.xdr, expiresAt: tx.expiresAt };
  }

  static async executeClaim(userId: string, proposalId: string, signedXdr: string) {
    const p = claimProposals.take(proposalId, userId);
    assertSignedMatches(proposalId, signedXdr);
    claimProposals.consume(proposalId);
    const r = await vault.submit(signedXdr);
    return {
      payrollId: p.meta.payrollId,
      status: 'COMPLETED' as const,
      amountUsd: stroopsToUsd(BigInt(r.returnValue as bigint)),
      hash: r.hash,
      explorerUrl: explorerTxUrl(r.hash),
    };
  }
}

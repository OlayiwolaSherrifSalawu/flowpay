import { randomUUID } from 'node:crypto';
import { InvalidRequestError, NotFoundError } from '../../core/errors.js';
import { Money } from '../../core/money.js';
import { isPostgresDb, prisma } from '../../db/index.js';
import type { BatchLegInput } from '../../stellar/batch.js';
import { recordActivity } from '../activity/record.js';
import { BatchPaymentService } from '../payments/batch_service.js';
import type { MissionAllocation, MissionIntent, MissionStatus } from './types.js';
import { MissionValidator } from './validator.js';

/**
 * Money Missions = saved rules owned by one user. FlowPay never holds user keys, so a
 * mission cannot move money on its own: every run is ONE atomic Stellar transaction
 * that the user reviews and signs on their device.
 *
 *   HOLD        → keep in the source currency (no operation)
 *   CONVERT_FX  → path payment to yourself (exact source amount)
 *   SWEEP_VAULT → convert if needed, then a claimable balance only you can claim after N days
 *   TRANSFER    → payment / path payment to the recipient
 */

export const DEFAULT_LOCK_DAYS = 30;

export interface EnrichedMission {
  id: string;
  userId: string;
  title: string;
  description: string;
  ruleType: string;
  isActive: boolean;
  is_active: boolean;
  status: MissionStatus;
  condition: Record<string, unknown>;
  action: Record<string, unknown>;
  allocations: MissionAllocation[];
  lastExecution: string | null;
  lastTransactionHash: string | null;
  executionCount: number;
  nextExecution: string;
  createdAt: string;
}

const missions = new Map<string, EnrichedMission>();

function asObject(val: unknown): Record<string, unknown> {
  if (!val) return {};
  if (typeof val === 'string') {
    try {
      const parsed = JSON.parse(val);
      return typeof parsed === 'object' && parsed ? parsed : {};
    } catch {
      return {};
    }
  }
  return typeof val === 'object' ? (val as Record<string, unknown>) : {};
}

function fromRow(row: any): EnrichedMission {
  const action = asObject(row.actionJson);
  const status = (action.status as MissionStatus) ?? (row.isActive ? 'ACTIVE' : 'PAUSED');
  return {
    id: row.id,
    userId: row.userId ?? '',
    title: row.title,
    description: row.description,
    ruleType: row.ruleType,
    isActive: row.isActive,
    is_active: row.isActive,
    status,
    condition: asObject(row.conditionJson),
    action,
    allocations: Array.isArray(action.allocations) ? (action.allocations as MissionAllocation[]) : [],
    lastExecution: (action.lastExecutedAt as string) ?? null,
    lastTransactionHash: (action.lastTransactionHash as string) ?? null,
    executionCount: Number(action.executionCount ?? 0),
    nextExecution: row.isActive ? 'Runs when you tap Run now' : 'Paused',
    createdAt: new Date(row.createdAt).toISOString(),
  };
}

async function save(m: EnrichedMission): Promise<void> {
  m.action = {
    ...m.action,
    status: m.status,
    allocations: m.allocations,
    lastExecutedAt: m.lastExecution,
    lastTransactionHash: m.lastTransactionHash,
    executionCount: m.executionCount,
  };
  missions.set(m.id, m);
  if (!isPostgresDb()) return;
  const data = {
    userId: m.userId,
    title: m.title,
    description: m.description,
    ruleType: m.ruleType,
    conditionJson: m.condition as any,
    actionJson: m.action as any,
    isActive: m.isActive,
  };
  try {
    await prisma.moneyMission.upsert({ where: { id: m.id }, create: { id: m.id, ...data }, update: data });
  } catch (err: any) {
    console.warn('[Missions] persistence failed:', err.message);
  }
}

/** Builds the transaction legs for one run of a mission. Returns [] when nothing moves. */
export function legsForMission(m: Pick<EnrichedMission, 'title' | 'condition' | 'allocations'>, now = Date.now()): BatchLegInput[] {
  const sourceCurrency = String(m.condition.sourceCurrency ?? 'USD').toUpperCase();
  const legs: BatchLegInput[] = [];
  for (const a of m.allocations) {
    const amountMinor = String(a.sourceAmountMinor ?? '0');
    if (BigInt(amountMinor) <= 0n || a.actionType === 'HOLD') continue;
    const target = String(a.targetCurrency ?? sourceCurrency).toUpperCase();
    const base = { label: a.label || m.title, mode: 'exact_send' as const, amount: { amountMinor, currency: sourceCurrency }, fundingCurrency: sourceCurrency, destCurrency: target };
    if (a.actionType === 'CONVERT_FX') {
      if (target === sourceCurrency) continue;
      legs.push({ ...base, to: 'self' });
    } else if (a.actionType === 'SWEEP_VAULT') {
      const days = Number((a as any).lockDays ?? DEFAULT_LOCK_DAYS);
      legs.push({ ...base, to: 'self', lockUntil: new Date(now + days * 86_400_000).toISOString() });
    } else if (a.actionType === 'TRANSFER') {
      if (!a.recipientIdentifier) throw new InvalidRequestError(`${a.label}: a recipient is required for transfers.`);
      legs.push({ ...base, to: a.recipientIdentifier });
    }
  }
  return legs;
}

export class MoneyMissionService {
  static async listMissions(userId: string): Promise<EnrichedMission[]> {
    if (isPostgresDb()) {
      try {
        const rows = await prisma.moneyMission.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
        for (const r of rows) missions.set(r.id, fromRow(r));
      } catch (err: any) {
        console.warn('[Missions] list failed, serving in-memory missions:', err.message);
      }
    }
    return [...missions.values()].filter((m) => m.userId === userId).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  static async getMission(id: string, userId: string): Promise<EnrichedMission> {
    let m = missions.get(id);
    if (!m && isPostgresDb()) {
      const row = await prisma.moneyMission.findUnique({ where: { id } });
      if (row) m = fromRow(row);
    }
    if (!m || m.userId !== userId) throw new NotFoundError('Mission not found.');
    return m;
  }

  /** Saves a validated rule (PENDING_APPROVAL) and prepares its first run for signing. */
  static async proposeMission(userId: string, intent: MissionIntent) {
    MissionValidator.validateOrThrow(intent);
    const mission: EnrichedMission = {
      id: `mission_${randomUUID()}`,
      userId,
      title: intent.ruleTitle,
      description: intent.explanation,
      ruleType: intent.intentType,
      isActive: false,
      is_active: false,
      status: 'PENDING_APPROVAL',
      condition: intent.triggerCondition as unknown as Record<string, unknown>,
      action: { destinationWallets: intent.destinationWallets },
      allocations: intent.allocations,
      lastExecution: null,
      lastTransactionHash: null,
      executionCount: 0,
      nextExecution: 'Awaiting your approval',
      createdAt: new Date().toISOString(),
    };
    await save(mission);
    const run = await this.prepareRun(mission.id, userId);
    return { ...run, ruleTitle: mission.title, allocations: mission.allocations, createdAt: mission.createdAt };
  }

  /** Builds this run's transaction. `proposal` is null when every allocation is HOLD. */
  static async prepareRun(missionId: string, userId: string, accountId?: string) {
    const mission = await this.getMission(missionId, userId);
    const legs = legsForMission(mission);
    if (legs.length === 0) return { missionId, proposal: null };
    const proposal = await BatchPaymentService.propose({
      userId,
      accountId,
      legs,
      memo: mission.title,
      context: { purpose: 'MISSION', reference: missionId },
    });
    return { missionId, proposal };
  }

  /**
   * Activates the mission and, if a signed run is provided, submits it. Activation of a
   * HOLD-only mission needs no transaction. A failed submission leaves the mission's
   * status unchanged and propagates the error.
   */
  static async executeMission(args: { missionId: string; userId: string; proposalId?: string; signedXdr?: string }) {
    const mission = await this.getMission(args.missionId, args.userId);
    let execution: Awaited<ReturnType<typeof BatchPaymentService.execute>> | null = null;
    if (args.proposalId || args.signedXdr) {
      if (!args.proposalId || !args.signedXdr) throw new InvalidRequestError('proposalId and signedXdr are required together.');
      execution = await BatchPaymentService.execute({ userId: args.userId, proposalId: args.proposalId, signedXdr: args.signedXdr });
    } else if (legsForMission(mission).length > 0) {
      throw new InvalidRequestError('This mission moves money; sign the prepared run to execute it.');
    }

    const executedAt = new Date().toISOString();
    mission.isActive = mission.is_active = true;
    mission.status = 'ACTIVE';
    if (execution) {
      mission.lastExecution = executedAt;
      mission.lastTransactionHash = execution.transactionHash;
      mission.executionCount += 1;
    }
    await save(mission);
    await recordActivity({
      action: execution ? 'MISSION_EXECUTED' : 'MISSION_ACTIVATED',
      actor: args.userId,
      details: {
        missionId: mission.id,
        rule: mission.title,
        status: 'COMPLETED',
        transactionHash: execution?.transactionHash,
        explorerUrl: execution?.explorerUrl,
        legs: execution?.legs,
        executedAt,
      },
    });
    return {
      success: true,
      missionId: mission.id,
      status: mission.status,
      executedAt,
      transactionHash: execution?.transactionHash ?? null,
      explorerUrl: execution?.explorerUrl ?? null,
      legs: execution?.legs ?? [],
    };
  }

  static async createMission(userId: string, data: { title: string; description: string; ruleType: string; condition: Record<string, unknown>; action: Record<string, unknown> }) {
    if (!data?.title) throw new InvalidRequestError('title is required');
    const mission: EnrichedMission = {
      id: `mission_${randomUUID()}`,
      userId,
      title: data.title,
      description: data.description ?? '',
      ruleType: data.ruleType ?? 'CUSTOM',
      isActive: true,
      is_active: true,
      status: 'ACTIVE',
      condition: data.condition ?? {},
      action: data.action ?? {},
      allocations: Array.isArray((data.action as any)?.allocations) ? (data.action as any).allocations : [],
      lastExecution: null,
      lastTransactionHash: null,
      executionCount: 0,
      nextExecution: 'Runs when you tap Run now',
      createdAt: new Date().toISOString(),
    };
    await save(mission);
    return mission;
  }

  static async toggleMission(id: string, userId: string) {
    const m = await this.getMission(id, userId);
    m.isActive = m.is_active = !m.isActive;
    m.status = m.isActive ? 'ACTIVE' : 'PAUSED';
    await save(m);
    return { ...m, rule_type: m.ruleType };
  }

  static async deleteMission(id: string, userId: string): Promise<boolean> {
    await this.getMission(id, userId);
    missions.delete(id);
    if (isPostgresDb()) {
      try {
        await prisma.moneyMission.delete({ where: { id } });
      } catch (err: any) {
        console.warn('[Missions] delete failed:', err.message);
      }
    }
    return true;
  }

  /** Approximate total of one run, in the mission's source currency. */
  static runTotal(m: Pick<EnrichedMission, 'condition' | 'allocations'>): Money {
    const currency = String(m.condition.sourceCurrency ?? 'USD').toUpperCase() as any;
    return m.allocations.reduce((sum, a) => sum.add(Money.fromMinor(a.sourceAmountMinor ?? '0', currency)), Money.zero(currency));
  }

  /** Testing hook. */
  static resetForTests(): void {
    missions.clear();
  }
}

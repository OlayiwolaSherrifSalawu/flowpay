import crypto from 'node:crypto';
import { env } from '../../config/env.js';
import { InvalidRequestError, NotFoundError, UnauthorizedError, FlowPayError, ValidationError } from '../../core/errors.js';
import { isPostgresDb, prisma } from '../../db/index.js';
import { isEmailVerified, registeredUsers } from '../../routes/auth.routes.js';
import { accountForUser } from '../../stellar/directory.js';
import { recordActivity } from '../activity/record.js';
import { mailService } from '../mail/service.js';

/**
 * Employees on Stellar.
 *
 *   employer adds employee → INVITED (+ single-use invite link, 72h)
 *   employee signs up, creates their wallet ON THEIR OWN DEVICE, proves ownership
 *   (signed challenge, see /api/wallets/register), then accepts the invite → READY
 *
 * The employer never holds the employee's keys. Invites are looked up by token only;
 * only a SHA-256 hash of the token is stored.
 */

export const SUPPORTED_EMPLOYEE_COUNTRIES = ['US', 'CA', 'MX', 'GB', 'NG'] as const;
const CURRENCY_BY_COUNTRY: Record<string, string> = { US: 'USD', CA: 'CAD', MX: 'MXN', GB: 'GBP', NG: 'NGN' };
const SUPPORTED_CURRENCIES = new Set(Object.values(CURRENCY_BY_COUNTRY));
const INVITE_TTL_MS = 72 * 60 * 60 * 1000;

export type EmployeeStatus = 'INVITED' | 'READY' | 'SUSPENDED';

export interface EmployeeRecord {
  id: string;
  businessId: string;
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber: string | null;
  country: string;
  targetCurrency: string;
  payrollAmountMinor: number;
  payrollCurrency: string;
  walletAddress: string | null;
  linkedUserId: string | null;
  status: EmployeeStatus | string;
  inviteTokenHash: string | null;
  inviteExpiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateEmployeeInput {
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber?: string;
  country: string;
  targetCurrency?: string;
  payrollAmountMinor: number;
  employerName?: string;
  companyName?: string;
}

export interface PublicInvite {
  employeeId: string;
  firstName: string;
  lastName: string;
  email: string;
  country: string;
  targetCurrency: string;
  payrollAmountMinor: number;
  companyName: string;
  expiresAt: string;
}

const employees = new Map<string, EmployeeRecord>();
/** Plaintext tokens for invites created in this process, so the employer can re-share the link. */
const shareableTokens = new Map<string, string>(); // employeeId -> token

export const hashInviteToken = (token: string) => crypto.createHash('sha256').update(token).digest('hex');

/** Employers own one business each: `biz_<ownerUserId>` (created at business signup). */
export const businessIdFor = (employerUserId: string) => `biz_${employerUserId}`;

function toRecord(row: any): EmployeeRecord {
  return {
    id: row.id,
    businessId: row.businessId,
    firstName: row.firstName,
    lastName: row.lastName,
    email: row.email,
    phoneNumber: row.phoneNumber ?? null,
    country: row.country,
    targetCurrency: row.targetCurrency,
    payrollAmountMinor: row.payrollAmountMinor,
    payrollCurrency: row.payrollCurrency ?? row.targetCurrency,
    walletAddress: row.walletAddress ?? null,
    linkedUserId: row.linkedUserId ?? null,
    status: row.status,
    inviteTokenHash: row.inviteTokenHash ?? null,
    inviteExpiresAt: row.inviteExpiresAt ? new Date(row.inviteExpiresAt) : null,
    createdAt: new Date(row.createdAt),
    updatedAt: new Date(row.updatedAt),
  };
}

async function persist(e: EmployeeRecord): Promise<void> {
  employees.set(e.id, e);
  if (!isPostgresDb()) return;
  const { id, ...data } = e;
  try {
    await prisma.employee.upsert({
      where: { id },
      create: { id, partnerId: 'stellar', ...data } as any,
      update: data as any,
    });
  } catch (err: any) {
    // The record stays in memory; surface the problem instead of pretending it's saved.
    throw new FlowPayError(`Could not save employee: ${err.message}`, 503, 'EMPLOYEE_PERSISTENCE_FAILED');
  }
}

/** Safe-for-clients view (never exposes the token hash). */
export function publicEmployee(e: EmployeeRecord) {
  const { inviteTokenHash: _hash, ...rest } = e;
  return {
    ...rest,
    hasWallet: !!e.walletAddress,
    inviteActive: !!e.inviteTokenHash && !!e.inviteExpiresAt && e.inviteExpiresAt.getTime() > Date.now() && e.status === 'INVITED',
  };
}

export class EmployeeService {
  static validateCreateInput(data: CreateEmployeeInput): { valid: boolean; errors: string[] } {
    const errors: string[] = [];
    if (!data?.firstName?.trim()) errors.push('firstName is required');
    if (!data?.lastName?.trim()) errors.push('lastName is required');
    if (!data?.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())) errors.push('A valid email address is required');
    const country = (data?.country || '').trim().toUpperCase();
    if (!(SUPPORTED_EMPLOYEE_COUNTRIES as readonly string[]).includes(country)) {
      errors.push(`country must be one of: ${SUPPORTED_EMPLOYEE_COUNTRIES.join(', ')} (received: ${data?.country})`);
    }
    if (data?.targetCurrency && !SUPPORTED_CURRENCIES.has(data.targetCurrency.toUpperCase())) {
      errors.push(`targetCurrency must be one of: ${[...SUPPORTED_CURRENCIES].join(', ')}`);
    }
    if (!Number.isInteger(data?.payrollAmountMinor) || data.payrollAmountMinor <= 0) {
      errors.push('payrollAmountMinor must be a positive integer in minor units (e.g. 100000 = 1,000.00)');
    }
    return { valid: errors.length === 0, errors };
  }

  static resolveCurrency(country: string): string {
    return CURRENCY_BY_COUNTRY[country.toUpperCase()] ?? 'USD';
  }

  static async listEmployees(employerUserId: string, statusFilter?: string): Promise<EmployeeRecord[]> {
    const businessId = businessIdFor(employerUserId);
    if (isPostgresDb()) {
      try {
        const rows = await prisma.employee.findMany({ where: { businessId }, orderBy: { createdAt: 'desc' } });
        for (const r of rows) employees.set(r.id, toRecord(r));
      } catch (err: any) {
        console.warn('[Employees] list from DB failed, serving in-memory records:', err.message);
      }
    }
    return [...employees.values()]
      .filter((e) => e.businessId === businessId)
      .filter((e) => !statusFilter || e.status.toUpperCase() === statusFilter.toUpperCase())
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  static async getEmployee(employerUserId: string, id: string): Promise<EmployeeRecord> {
    let e = employees.get(id);
    if (!e && isPostgresDb()) {
      const row = await prisma.employee.findUnique({ where: { id } });
      if (row) e = toRecord(row);
    }
    if (!e || e.businessId !== businessIdFor(employerUserId)) throw new NotFoundError('Employee not found.');
    return e;
  }

  static async createEmployee(employerUserId: string, data: CreateEmployeeInput) {
    const validation = this.validateCreateInput(data);
    if (!validation.valid) throw new ValidationError(validation.errors.join('; '), validation.errors);

    const email = data.email.trim().toLowerCase();
    const businessId = businessIdFor(employerUserId);
    const existing = (await this.listEmployees(employerUserId)).find((e) => e.email === email);
    if (existing) throw new InvalidRequestError(`${email} is already on your team.`);

    const country = data.country.trim().toUpperCase();
    const targetCurrency = (data.targetCurrency || this.resolveCurrency(country)).toUpperCase();
    const token = crypto.randomBytes(24).toString('hex');
    const now = new Date();
    const employee: EmployeeRecord = {
      id: `emp_${crypto.randomUUID()}`,
      businessId,
      firstName: data.firstName.trim(),
      lastName: data.lastName.trim(),
      email,
      phoneNumber: data.phoneNumber?.trim() || null,
      country,
      targetCurrency,
      payrollAmountMinor: data.payrollAmountMinor,
      payrollCurrency: targetCurrency,
      walletAddress: null,
      linkedUserId: null,
      status: 'INVITED',
      inviteTokenHash: hashInviteToken(token),
      inviteExpiresAt: new Date(now.getTime() + INVITE_TTL_MS),
      createdAt: now,
      updatedAt: now,
    };
    await persist(employee);
    shareableTokens.set(employee.id, token);

    const inviteUrl = `${env.APP_URL.replace(/\/$/, '')}/invite/${token}`;
    const companyName = data.companyName || registeredUsers.get(employerUserId)?.companyName || 'Your employer';
    // Email is a convenience; the employer also gets the link to share directly.
    let inviteEmailSent = false;
    try {
      const res = await mailService.sendEmployeeInvite({
        to: email,
        recipientName: `${employee.firstName} ${employee.lastName}`,
        employerName: data.employerName || companyName,
        companyName,
        country,
        currency: targetCurrency,
        payrollAmount: (employee.payrollAmountMinor / 100).toFixed(2),
        inviteUrl,
      });
      inviteEmailSent = !!res.success;
    } catch (err: any) {
      console.warn('[Employees] invite email failed:', err?.message || err);
    }
    await recordActivity({ category: 'BUSINESS', action: 'EMPLOYEE_INVITED', actor: employerUserId, details: { employeeId: employee.id, email, country, targetCurrency } });

    return { employee, inviteToken: token, inviteUrl, inviteEmailSent };
  }

  /** Issues a fresh invite link (invalidating the old one). Only for employees not yet linked. */
  static async resendInvite(employerUserId: string, employeeId: string) {
    const e = await this.getEmployee(employerUserId, employeeId);
    if (e.status !== 'INVITED') throw new InvalidRequestError('This employee has already joined.');
    const token = crypto.randomBytes(24).toString('hex');
    e.inviteTokenHash = hashInviteToken(token);
    e.inviteExpiresAt = new Date(Date.now() + INVITE_TTL_MS);
    e.updatedAt = new Date();
    await persist(e);
    shareableTokens.set(e.id, token);
    return { employee: e, inviteToken: token, inviteUrl: `${env.APP_URL.replace(/\/$/, '')}/invite/${token}` };
  }

  private static async findByInviteToken(token: string): Promise<EmployeeRecord> {
    if (!/^[0-9a-f]{48}$/.test(token ?? '')) throw new NotFoundError('This invitation link is not valid.');
    const hash = hashInviteToken(token);
    let e = [...employees.values()].find((x) => x.inviteTokenHash === hash);
    if (!e && isPostgresDb()) {
      const row = await prisma.employee.findFirst({ where: { inviteTokenHash: hash } });
      if (row) e = toRecord(row);
    }
    if (!e) throw new NotFoundError('This invitation link is not valid or was replaced by a newer one.');
    if (e.status !== 'INVITED') {
      throw Object.assign(new FlowPayError('This invitation has already been accepted.', 410, 'ALREADY_USED'), {});
    }
    if (!e.inviteExpiresAt || e.inviteExpiresAt.getTime() < Date.now()) {
      throw new FlowPayError('This invitation has expired. Ask your employer to send a new one.', 410, 'EXPIRED');
    }
    return e;
  }

  static async getInviteDetails(token: string): Promise<PublicInvite> {
    const e = await this.findByInviteToken(token);
    const owner = e.businessId.replace(/^biz_/, '');
    return {
      employeeId: e.id,
      firstName: e.firstName,
      lastName: e.lastName,
      email: e.email,
      country: e.country,
      targetCurrency: e.targetCurrency,
      payrollAmountMinor: e.payrollAmountMinor,
      companyName: registeredUsers.get(owner)?.companyName ?? 'Your employer',
      expiresAt: e.inviteExpiresAt!.toISOString(),
    };
  }

  /**
   * The invited person accepts: they must be signed in as a FlowPay user with the SAME
   * email as the invite, and must already have proven ownership of a Stellar account
   * (wallet registration). That account becomes their payroll destination.
   */
  static async acceptInvite(args: { token: string; requestingUserId: string }) {
    const e = await this.findByInviteToken(args.token);
    const user = registeredUsers.get(args.requestingUserId) ??
      (isPostgresDb() ? await prisma.user.findUnique({ where: { id: args.requestingUserId } }).then((u) => u && { email: u.email, fullName: u.fullName }) : null);
    if (!user) throw new UnauthorizedError('Sign in to accept this invitation.');
    if (user.email.toLowerCase() !== e.email) {
      throw new FlowPayError('This invitation was sent to a different email address.', 403, 'FORBIDDEN');
    }
    if (!(await isEmailVerified(args.requestingUserId))) {
      throw new FlowPayError('Verify your email address first — we\'ll send you a code.', 403, 'EMAIL_NOT_VERIFIED');
    }
    const accountId = await accountForUser(args.requestingUserId);
    if (!accountId) throw new InvalidRequestError('Set up and activate your wallet first, then accept the invitation.');

    e.walletAddress = accountId;
    e.linkedUserId = args.requestingUserId;
    e.status = 'READY';
    e.inviteTokenHash = null; // single use
    e.inviteExpiresAt = null;
    e.updatedAt = new Date();
    await persist(e);
    shareableTokens.delete(e.id);
    await recordActivity({
      category: 'BUSINESS',
      action: 'EMPLOYEE_JOINED',
      actor: e.businessId.replace(/^biz_/, ''),
      details: { employeeId: e.id, name: `${e.firstName} ${e.lastName}`, stellarAccountId: accountId },
    });
    return e;
  }

  static async updateEmployee(employerUserId: string, id: string, patch: { status?: string; payrollAmountMinor?: number }) {
    const e = await this.getEmployee(employerUserId, id);
    if (patch.status !== undefined) {
      const status = patch.status.toUpperCase();
      if (status === 'SUSPENDED') e.status = 'SUSPENDED';
      else if (status === 'READY' && e.walletAddress) e.status = 'READY';
      else if (status === 'INVITED' && !e.walletAddress) e.status = 'INVITED';
      else throw new InvalidRequestError(`Can't move this employee to ${status}.`);
    }
    if (patch.payrollAmountMinor !== undefined) {
      if (!Number.isInteger(patch.payrollAmountMinor) || patch.payrollAmountMinor <= 0) throw new ValidationError('payrollAmountMinor must be a positive integer');
      e.payrollAmountMinor = patch.payrollAmountMinor;
    }
    e.updatedAt = new Date();
    await persist(e);
    return e;
  }

  /** The current shareable link for an INVITED employee created in this process, if any. */
  static shareableInviteUrl(employeeId: string): string | null {
    const token = shareableTokens.get(employeeId);
    return token ? `${env.APP_URL.replace(/\/$/, '')}/invite/${token}` : null;
  }

  /** Testing hook. */
  static resetForTests(): void {
    employees.clear();
    shareableTokens.clear();
  }
}

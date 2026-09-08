import crypto from 'node:crypto';
import { bmoniClient } from '../../bmoni/client.js';
import { prisma, isPostgresDb } from '../../db/index.js';
import { env } from '../../config/env.js';
import { mailService } from '../mail/service.js';
import { FlowPayError, BmoniUnavailableError } from '../../core/errors.js';

export type EmployeeLifecycleStage =
  | 'INVITED'
  | 'CREATED'
  | 'WALLET_PENDING'
  | 'KYC_PENDING'
  | 'ONBOARDING'
  | 'READY'
  | 'FAILED'
  | 'LINKED'
  | 'ACTIVE';

export type EmployeeRecord = NonNullable<Awaited<ReturnType<typeof prisma.employee.findFirst>>>;

export interface CreateEmployeeInput {
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber?: string;
  country: string;
  targetCurrency?: string;
  payrollAmountMinor: number;
  payrollCurrency?: string;
}

export interface EmployeeInviteRecord {
  token: string;
  employeeId: string;
  bmoniUserId?: string;
  email: string;
  firstName: string;
  lastName: string;
  country: string;
  targetCurrency: string;
  payrollAmountMinor: number;
  expiresAt: Date;
  usedAt?: Date;
}

export interface LinkEmployeeWalletInput {
  employeeId?: string;
  inviteToken: string;
  bmoniUserId: string;
  walletAddress: string;
  walletId?: string;
  requestingUserId?: string;
  requestingEmail?: string;
}

// In-memory invite registry (72h TTL) and fallback store
export const employeeInvites = new Map<string, EmployeeInviteRecord>();
export const inMemoryEmployees = new Map<string, any>();

export class EmployeeService {
  static validateCreateInput(data: CreateEmployeeInput): { valid: boolean; errors: string[] } {
    const errors: string[] = [];
    if (!data.firstName || typeof data.firstName !== 'string' || data.firstName.trim().length === 0) errors.push('firstName is required and cannot be empty');
    if (!data.lastName || typeof data.lastName !== 'string' || data.lastName.trim().length === 0) errors.push('lastName is required and cannot be empty');
    if (!data.email || typeof data.email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())) errors.push('A valid email address is required');
    const country = (data.country || '').trim().toUpperCase();
    const supportedCountries = ['NG', 'MX', 'CA'];
    if (!supportedCountries.includes(country)) errors.push(`country must be one of: ${supportedCountries.join(', ')} (received: ${data.country})`);
    if (!Number.isInteger(data.payrollAmountMinor) || data.payrollAmountMinor <= 0) errors.push('payrollAmountMinor must be a positive integer in minor currency units (e.g. 100000 = $1,000.00)');
    return { valid: errors.length === 0, errors };
  }

  static resolveCurrency(country: string): string {
    switch (country.toUpperCase()) { case 'NG': return 'NGN'; case 'MX': return 'MXN'; case 'CA': return 'CAD'; default: return 'USD'; }
  }

  static async listEmployees(statusFilter?: string): Promise<EmployeeRecord[]> {
    if (isPostgresDb()) {
      try { return await prisma.employee.findMany({ where: statusFilter ? { status: statusFilter.toUpperCase() } : undefined, orderBy: { createdAt: 'desc' } }); }
      catch (err) { console.warn('[EmployeeService] listEmployees error:', err); return []; }
    }
    const all = Array.from(inMemoryEmployees.values());
    if (statusFilter) {
      return all.filter((e) => e.status?.toUpperCase() === statusFilter.toUpperCase()) as EmployeeRecord[];
    }
    return all as EmployeeRecord[];
  }

  static async getEmployeeById(id: string): Promise<EmployeeRecord | undefined> {
    if (isPostgresDb()) {
      try { return await prisma.employee.findUnique({ where: { id } }) ?? undefined; }
      catch (err) { console.warn('[EmployeeService] getEmployeeById error:', err); return undefined; }
    }
    return (inMemoryEmployees.get(id) || undefined) as EmployeeRecord | undefined;
  }

  static generateInviteToken(): string {
    return crypto.randomBytes(24).toString('hex');
  }

  static async createEmployee(data: CreateEmployeeInput): Promise<{
    employee: EmployeeRecord;
    bmoniUserId?: string;
    inviteToken: string;
    inviteCode: string;
    inviteUrl: string;
  }> {
    const validation = this.validateCreateInput(data);
    if (!validation.valid) { const error = new Error(validation.errors.join('; ')) as Error & { statusCode?: number; errors?: string[] }; error.statusCode = 400; error.errors = validation.errors; throw error; }
    const country = data.country.trim().toUpperCase();
    const targetCurrency = data.targetCurrency?.toUpperCase() || this.resolveCurrency(country);
    const payrollCurrency = data.payrollCurrency?.toUpperCase() || targetCurrency;
    const id = `emp_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    let bmoniUserId: string | undefined;
    let createError: unknown;
    try {
      const user = await bmoniClient.createEmployeeUser({
        firstName: data.firstName.trim(),
        lastName: data.lastName.trim(),
        email: data.email.trim().toLowerCase(),
        phoneNumber: data.phoneNumber?.trim(),
      });
      bmoniUserId = user.bmoniUserId || user.id;
    } catch (err: unknown) {
      console.error('[EmployeeService] Failed to create BMONI user for employee:', err);
      createError = err;
    }

    const inviteToken = this.generateInviteToken();
    const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000); // 72 hours single-use TTL
    const inviteUrl = `https://app.flowpay.finance/invite/${inviteToken}`;

    const employeeData = {
      id,
      bmoniUserId: bmoniUserId || null,
      partnerId: env.BMONI_PARTNER_ID,
      firstName: data.firstName.trim(),
      lastName: data.lastName.trim(),
      email: data.email.trim().toLowerCase(),
      phoneNumber: data.phoneNumber?.trim() || null,
      country,
      targetCurrency,
      payrollAmountMinor: data.payrollAmountMinor,
      payrollCurrency,
      status: bmoniUserId ? 'INVITED' : 'FAILED',
      failedStage: bmoniUserId ? null : 'BMONI_USER_CREATION',
      walletId: null,
      walletAddress: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    let employee: EmployeeRecord;
    if (isPostgresDb()) {
      employee = await prisma.employee.create({ data: employeeData as any });
    } else {
      employee = employeeData as unknown as EmployeeRecord;
    }
    inMemoryEmployees.set(id, employee);

    // Register active invite record
    const inviteRecord: EmployeeInviteRecord = {
      token: inviteToken,
      employeeId: id,
      bmoniUserId: employeeData.bmoniUserId || undefined,
      email: employeeData.email,
      firstName: employeeData.firstName,
      lastName: employeeData.lastName,
      country: employeeData.country,
      targetCurrency: employeeData.targetCurrency,
      payrollAmountMinor: employeeData.payrollAmountMinor,
      expiresAt,
    };
    employeeInvites.set(inviteToken, inviteRecord);

    if (createError) {
      if (createError instanceof FlowPayError) {
        throw createError;
      }
      throw new BmoniUnavailableError(
        `Failed to create BMONI user: ${createError instanceof Error ? createError.message : 'BMONI user creation failed'}. Employee record saved with status FAILED.`
      );
    }

    return {
      employee,
      bmoniUserId,
      inviteToken,
      inviteCode: inviteToken,
      inviteUrl,
    };
  }

  static async getInviteDetails(codeOrId: string): Promise<EmployeeInviteRecord> {
    const trimmed = (codeOrId || '').trim();
    // Normalize if flowpay_ prefix is attached
    const tokenOrId = trimmed.startsWith('flowpay_') ? trimmed.substring(8) : trimmed;

    // 1. Check direct token in memory
    let invite = employeeInvites.get(tokenOrId);

    // 2. Check if searching by employeeId in memory
    if (!invite) {
      for (const rec of employeeInvites.values()) {
        if (rec.employeeId === tokenOrId || rec.token === tokenOrId) {
          invite = rec;
          break;
        }
      }
    }

    // 3. Fallback: check database for employee record if restarted
    if (!invite) {
      let dbEmployee: EmployeeRecord | undefined;
      if (isPostgresDb()) {
        try {
          dbEmployee = await prisma.employee.findFirst({
            where: { OR: [{ id: tokenOrId }, { email: tokenOrId }] },
          }) ?? undefined;
        } catch (_) {}
      } else {
        dbEmployee = inMemoryEmployees.get(tokenOrId) as EmployeeRecord | undefined;
      }

      if (dbEmployee && dbEmployee.status === 'INVITED') {
        const fallbackToken = this.generateInviteToken();
        invite = {
          token: fallbackToken,
          employeeId: dbEmployee.id,
          bmoniUserId: dbEmployee.bmoniUserId || undefined,
          email: dbEmployee.email,
          firstName: dbEmployee.firstName,
          lastName: dbEmployee.lastName,
          country: dbEmployee.country,
          targetCurrency: dbEmployee.targetCurrency,
          payrollAmountMinor: dbEmployee.payrollAmountMinor,
          expiresAt: new Date(Date.now() + 72 * 60 * 60 * 1000),
        };
        employeeInvites.set(fallbackToken, invite);
      }
    }

    if (!invite) {
      const err = new Error(`Invitation "${codeOrId}" was not found or is invalid.`) as Error & { statusCode?: number; code?: string };
      err.statusCode = 404;
      err.code = 'NOT_FOUND';
      throw err;
    }

    // 4. Validate single-use status
    if (invite.usedAt) {
      const err = new Error('This invitation has already been used and employee wallet is linked.') as Error & { statusCode?: number; code?: string };
      err.statusCode = 410;
      err.code = 'ALREADY_USED';
      throw err;
    }

    // 5. Validate expiration
    if (new Date() > invite.expiresAt) {
      const err = new Error('This invitation has expired. Please request a new invite from your employer.') as Error & { statusCode?: number; code?: string };
      err.statusCode = 410;
      err.code = 'EXPIRED';
      throw err;
    }

    return invite;
  }

  static async linkEmployeeWallet(input: LinkEmployeeWalletInput): Promise<EmployeeRecord> {
    if (!input.requestingUserId && !input.requestingEmail) {
      const err = new Error('Authentication required: valid employee session required to link wallet.') as Error & { statusCode?: number; code?: string };
      err.statusCode = 401;
      err.code = 'UNAUTHORIZED';
      throw err;
    }

    // 1. Resolve and validate invite token (unexpired & unused)
    const invite = await this.getInviteDetails(input.inviteToken);

    // 2. Verify requesting session matches invited employee
    const reqUser = (input.requestingUserId || '').trim();
    const reqEmail = (input.requestingEmail || '').trim().toLowerCase();
    const targetEmail = invite.email.toLowerCase();

    let isMatch = false;

    // Direct email match if passed in session
    if (reqEmail && reqEmail === targetEmail) {
      isMatch = true;
    }

    // Pre-provisioned BMONI identity match on the invited employee
    if (invite.bmoniUserId && reqUser && reqUser === invite.bmoniUserId) {
      isMatch = true;
    }

    // Match employee ID
    if (reqUser && reqUser === invite.employeeId) {
      isMatch = true;
    }

    // Match registered user email in DB if Postgres is active
    if (!isMatch && reqUser && isPostgresDb()) {
      try {
        const dbUser = await prisma.user.findFirst({
          where: { OR: [{ id: reqUser }, { bmoniUserId: reqUser }] },
        });
        if (dbUser && dbUser.email.toLowerCase() === targetEmail) {
          isMatch = true;
        }
      } catch (_) {}
    }

    if (!isMatch) {
      const err = new Error('Forbidden: Your authenticated session does not match the invited employee record.') as Error & { statusCode?: number; code?: string };
      err.statusCode = 403;
      err.code = 'FORBIDDEN';
      throw err;
    }

    // 3. Mark invite as used (single-use enforcement)
    invite.usedAt = new Date();
    employeeInvites.set(invite.token, invite);

    // 4. Update employee record to READY with employee's own hardware wallet
    const updateData = {
      bmoniUserId: input.bmoniUserId,
      walletAddress: input.walletAddress,
      walletId: input.walletId || null,
      status: 'READY',
      failedStage: null,
      updatedAt: new Date(),
    };

    let updated: EmployeeRecord | undefined;
    if (isPostgresDb()) {
      try {
        updated = await prisma.employee.update({
          where: { id: invite.employeeId },
          data: updateData,
        });
      } catch (err) {
        console.warn('[EmployeeService] linkEmployeeWallet DB update error:', err);
      }
    }

    const existingInMemory = inMemoryEmployees.get(invite.employeeId) || {};
    updated = {
      ...existingInMemory,
      ...updateData,
      id: invite.employeeId,
      email: invite.email,
      firstName: invite.firstName,
      lastName: invite.lastName,
      country: invite.country,
      targetCurrency: invite.targetCurrency,
      payrollAmountMinor: invite.payrollAmountMinor,
    } as EmployeeRecord;

    inMemoryEmployees.set(invite.employeeId, updated);
    return updated;
  }

  static async updateEmployeeStatus(id: string, status: EmployeeLifecycleStage | string, failedStage?: string): Promise<EmployeeRecord | undefined> {
    if (isPostgresDb()) {
      try { return await prisma.employee.update({ where: { id }, data: { status: status.toUpperCase(), failedStage: failedStage || null } }); }
      catch (err) { console.warn('[EmployeeService] updateEmployeeStatus error:', err); return undefined; }
    }
    const emp = inMemoryEmployees.get(id);
    if (emp) {
      emp.status = status.toUpperCase();
      emp.failedStage = failedStage || null;
      inMemoryEmployees.set(id, emp);
      return emp as EmployeeRecord;
    }
    return undefined;
  }

  static async inviteEmployee(data: { firstName: string; lastName: string; email: string; phoneNumber?: string; country: string; targetCurrency?: string; payrollAmount?: number }): Promise<{ employee: EmployeeRecord; inviteUrl: string; inviteToken: string; inviteCode: string }> {
    const result = await this.createEmployee({ ...data, payrollAmountMinor: data.payrollAmount || 100000 });

    // Dispatch branded invitation email asynchronously
    mailService
      .sendEmployeeInvite({
        to: result.employee.email,
        recipientName: `${result.employee.firstName} ${result.employee.lastName}`.trim(),
        country: result.employee.country,
        currency: result.employee.payrollCurrency || undefined,
        payrollAmount: (result.employee.payrollAmountMinor / 100).toFixed(2),
        inviteUrl: result.inviteUrl,
      })
      .catch((err) => {
        console.warn('[EmployeeService] Failed to dispatch employee invite email:', err.message || err);
      });

    return {
      employee: result.employee,
      inviteUrl: result.inviteUrl,
      inviteToken: result.inviteToken,
      inviteCode: result.inviteCode,
    };
  }
}


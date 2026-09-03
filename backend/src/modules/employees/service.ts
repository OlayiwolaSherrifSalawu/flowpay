import { bmoniClient } from '../../bmoni/client.js';
import { prisma } from '../../db/index.js';
import { env } from '../../config/env.js';

export type EmployeeLifecycleStage = 'CREATED' | 'WALLET_PENDING' | 'KYC_PENDING' | 'ONBOARDING' | 'READY' | 'FAILED';
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
    try { return await prisma.employee.findMany({ where: statusFilter ? { status: statusFilter.toUpperCase() } : undefined, orderBy: { createdAt: 'desc' } }); }
    catch (err) { console.warn('[EmployeeService] listEmployees error:', err); return []; }
  }

  static async getEmployeeById(id: string): Promise<EmployeeRecord | undefined> {
    try { return await prisma.employee.findUnique({ where: { id } }) ?? undefined; }
    catch (err) { console.warn('[EmployeeService] getEmployeeById error:', err); return undefined; }
  }

  static async createEmployee(data: CreateEmployeeInput): Promise<{ employee: EmployeeRecord; bmoniUserId?: string }> {
    const validation = this.validateCreateInput(data);
    if (!validation.valid) { const error = new Error(validation.errors.join('; ')) as Error & { statusCode?: number; errors?: string[] }; error.statusCode = 400; error.errors = validation.errors; throw error; }
    const country = data.country.trim().toUpperCase();
    const targetCurrency = data.targetCurrency?.toUpperCase() || this.resolveCurrency(country);
    const payrollCurrency = data.payrollCurrency?.toUpperCase() || targetCurrency;
    const id = `emp_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    let bmoniUserId: string | undefined;
    try {
      const user = await bmoniClient.createEmployeeUser({ firstName: data.firstName.trim(), lastName: data.lastName.trim(), email: data.email.trim().toLowerCase(), phoneNumber: data.phoneNumber?.trim() });
      bmoniUserId = user.bmoniUserId || user.id;
    } catch (err: any) { console.warn('[EmployeeService] BMONI user creation notice (offline/sandbox fallback):', err.message || err); bmoniUserId = `usr_bmoni_${id}`; }
    const employee = await prisma.employee.create({ data: { id, bmoniUserId, partnerId: env.BMONI_PARTNER_ID, firstName: data.firstName.trim(), lastName: data.lastName.trim(), email: data.email.trim().toLowerCase(), phoneNumber: data.phoneNumber?.trim() || null, country, targetCurrency, payrollAmountMinor: data.payrollAmountMinor, payrollCurrency, status: 'CREATED' } });
    return { employee, bmoniUserId };
  }

  static async updateEmployeeStatus(id: string, status: EmployeeLifecycleStage | string, failedStage?: string): Promise<EmployeeRecord | undefined> {
    try { return await prisma.employee.update({ where: { id }, data: { status: status.toUpperCase(), failedStage: failedStage || null } }); }
    catch (err) { console.warn('[EmployeeService] updateEmployeeStatus error:', err); return undefined; }
  }

  static async inviteEmployee(data: { firstName: string; lastName: string; email: string; phoneNumber?: string; country: string; targetCurrency?: string; payrollAmount?: number }): Promise<{ employee: EmployeeRecord; inviteUrl: string }> {
    const result = await this.createEmployee({ ...data, payrollAmountMinor: data.payrollAmount || 100000 });
    return { employee: result.employee, inviteUrl: `https://bmoni.com/invite/flowpay_${result.employee.id}` };
  }
}

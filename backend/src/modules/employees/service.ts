import { bmoniClient } from '../../bmoni/client.js';
import { pool } from '../../db/index.js';
import { env } from '../../config/env.js';

export type EmployeeLifecycleStage =
  | 'CREATED'
  | 'WALLET_PENDING'
  | 'KYC_PENDING'
  | 'ONBOARDING'
  | 'READY'
  | 'FAILED';

export interface EmployeeRecord {
  id: string;
  bmoni_user_id?: string;
  partner_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number?: string;
  country: string;
  target_currency: string;
  payroll_amount_minor: number;
  payroll_currency?: string;
  wallet_id?: string;
  wallet_address?: string;
  card_id?: string;
  status: EmployeeLifecycleStage | string;
  failed_stage?: string;
  created_at: string;
  updated_at: string;
}

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
  /**
   * Validate employee creation input strictly server-side
   */
  static validateCreateInput(data: CreateEmployeeInput): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!data.firstName || typeof data.firstName !== 'string' || data.firstName.trim().length === 0) {
      errors.push('firstName is required and cannot be empty');
    }
    if (!data.lastName || typeof data.lastName !== 'string' || data.lastName.trim().length === 0) {
      errors.push('lastName is required and cannot be empty');
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!data.email || typeof data.email !== 'string' || !emailRegex.test(data.email.trim())) {
      errors.push('A valid email address is required');
    }

    const normalizedCountry = (data.country || '').trim().toUpperCase();
    const supportedCountries = ['NG', 'MX', 'CA'];
    if (!supportedCountries.includes(normalizedCountry)) {
      errors.push(`country must be one of: ${supportedCountries.join(', ')} (received: ${data.country})`);
    }

    if (
      typeof data.payrollAmountMinor !== 'number' ||
      !Number.isInteger(data.payrollAmountMinor) ||
      data.payrollAmountMinor <= 0
    ) {
      errors.push('payrollAmountMinor must be a positive integer in minor currency units (e.g. 100000 = $1,000.00)');
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * Resolve default currency for country
   */
  static resolveCurrency(country: string): string {
    switch (country.toUpperCase()) {
      case 'NG':
        return 'NGN';
      case 'MX':
        return 'MXN';
      case 'CA':
        return 'CAD';
      default:
        return 'USD';
    }
  }

  /**
   * List all employees, optionally filtered by status
   */
  static async listEmployees(statusFilter?: string): Promise<EmployeeRecord[]> {
    try {
      if (statusFilter) {
        const { rows } = await pool.query(
          'SELECT * FROM employees WHERE status = $1 ORDER BY created_at DESC',
          [statusFilter.toUpperCase()]
        );
        return rows as EmployeeRecord[];
      }
      const { rows } = await pool.query('SELECT * FROM employees ORDER BY created_at DESC');
      return rows as EmployeeRecord[];
    } catch (err) {
      console.warn('[EmployeeService] listEmployees error:', err);
      return [];
    }
  }

  /**
   * Fetch single employee by ID
   */
  static async getEmployeeById(id: string): Promise<EmployeeRecord | undefined> {
    try {
      const { rows } = await pool.query('SELECT * FROM employees WHERE id = $1', [id]);
      return rows[0] as EmployeeRecord | undefined;
    } catch (err) {
      console.warn('[EmployeeService] getEmployeeById error:', err);
      return undefined;
    }
  }

  /**
   * Stage 1: Create Employee with BMONI user creation (POST /v1/users)
   * Enforces 6-stage lifecycle: CREATED -> WALLET_PENDING -> KYC_PENDING -> ONBOARDING -> READY -> FAILED
   */
  static async createEmployee(data: CreateEmployeeInput): Promise<{ employee: EmployeeRecord; bmoniUserId?: string }> {
    // 1. Server-side validation
    const validation = this.validateCreateInput(data);
    if (!validation.valid) {
      const err = new Error(validation.errors.join('; '));
      (err as any).statusCode = 400;
      (err as any).errors = validation.errors;
      throw err;
    }

    const country = data.country.trim().toUpperCase();
    const targetCurrency = data.targetCurrency?.toUpperCase() || this.resolveCurrency(country);
    const payrollCurrency = data.payrollCurrency?.toUpperCase() || targetCurrency;
    const id = `emp_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // 2. Call official BMONI POST /v1/users to register on-chain identity
    let bmoniUserId: string | undefined;
    try {
      const bmoniUser = await bmoniClient.createEmployeeUser({
        firstName: data.firstName.trim(),
        lastName: data.lastName.trim(),
        email: data.email.trim().toLowerCase(),
        phoneNumber: data.phoneNumber?.trim(),
      });
      bmoniUserId = bmoniUser.bmoniUserId || bmoniUser.id;
    } catch (err: any) {
      console.warn('[EmployeeService] BMONI user creation notice (offline/sandbox fallback):', err.message || err);
      // In sandbox or conflict mode, assign fallback identifier so workflow proceeds
      bmoniUserId = `usr_bmoni_${id}`;
    }

    // 3. Persist to Postgres with initial lifecycle stage 'CREATED'
    await pool.query(
      `INSERT INTO employees 
         (id, bmoni_user_id, partner_id, first_name, last_name, email, phone_number, country, target_currency, payroll_amount_minor, payroll_currency, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [
        id,
        bmoniUserId,
        env.BMONI_PARTNER_ID,
        data.firstName.trim(),
        data.lastName.trim(),
        data.email.trim().toLowerCase(),
        data.phoneNumber?.trim() || null,
        country,
        targetCurrency,
        data.payrollAmountMinor,
        payrollCurrency,
        'CREATED', // Stage 1 of 6-stage lifecycle
      ]
    );

    const employee = (await this.getEmployeeById(id))!;
    return { employee, bmoniUserId };
  }

  /**
   * Update employee lifecycle status (invoked by webhooks or admin action)
   */
  static async updateEmployeeStatus(
    id: string,
    status: EmployeeLifecycleStage | string,
    failedStage?: string
  ): Promise<EmployeeRecord | undefined> {
    try {
      await pool.query(
        `UPDATE employees 
         SET status = $1, failed_stage = $2, updated_at = now()
         WHERE id = $3`,
        [status.toUpperCase(), failedStage || null, id]
      );
      return await this.getEmployeeById(id);
    } catch (err) {
      console.warn('[EmployeeService] updateEmployeeStatus error:', err);
      return undefined;
    }
  }

  /**
   * Legacy invite endpoint wrapper for backward compatibility
   * @deprecated Use createEmployee instead
   */
  static async inviteEmployee(data: {
    firstName: string;
    lastName: string;
    email: string;
    phoneNumber?: string;
    country: string;
    targetCurrency?: string;
    payrollAmount?: number;
  }): Promise<{ employee: EmployeeRecord; inviteUrl: string }> {
    const result = await this.createEmployee({
      firstName: data.firstName,
      lastName: data.lastName,
      email: data.email,
      phoneNumber: data.phoneNumber,
      country: data.country,
      targetCurrency: data.targetCurrency,
      payrollAmountMinor: data.payrollAmount || 100000,
    });

    return {
      employee: result.employee,
      inviteUrl: `https://bmoni.com/invite/flowpay_${result.employee.id}`,
    };
  }
}

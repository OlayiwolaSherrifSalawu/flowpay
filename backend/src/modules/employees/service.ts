import { bmoniClient } from '../../bmoni/client.js';
import { pool } from '../../db/index.js';
import { env } from '../../config/env.js';

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
  wallet_id?: string;
  wallet_address?: string;
  card_id?: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export class EmployeeService {
  static async listEmployees(): Promise<EmployeeRecord[]> {
    try {
      const { rows } = await pool.query('SELECT * FROM employees ORDER BY created_at DESC');
      return rows as EmployeeRecord[];
    } catch (err) {
      console.warn('[EmployeeService] listEmployees error:', err);
      return [];
    }
  }

  static async getEmployeeById(id: string): Promise<EmployeeRecord | undefined> {
    try {
      const { rows } = await pool.query('SELECT * FROM employees WHERE id = $1', [id]);
      return rows[0] as EmployeeRecord | undefined;
    } catch (err) {
      console.warn('[EmployeeService] getEmployeeById error:', err);
      return undefined;
    }
  }

  static async inviteEmployee(data: {
    firstName: string;
    lastName: string;
    email: string;
    phoneNumber?: string;
    country: string;
    targetCurrency: string;
  }): Promise<{ employee: EmployeeRecord; inviteUrl: string }> {
    const id = `emp_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    
    // 1. Call BMONI partner employee invite endpoint
    let inviteUrl = `https://bmoni.com/invite/flowpay_${id}`;
    try {
      const res = await bmoniClient.inviteEmployee({
        name: `${data.firstName} ${data.lastName}`,
        email: data.email,
        country: data.country,
      });
      if (res.inviteUrl) {
        inviteUrl = res.inviteUrl;
      }
    } catch (err) {
      console.warn('[EmployeeService] BMONI invite fallback (offline/sandbox):', err);
    }

    // 2. Insert into Postgres
    await pool.query(
      `INSERT INTO employees 
         (id, partner_id, first_name, last_name, email, phone_number, country, target_currency, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        id,
        env.BMONI_PARTNER_ID,
        data.firstName,
        data.lastName,
        data.email,
        data.phoneNumber ?? null,
        data.country,
        data.targetCurrency,
        'INVITED',
      ]
    );

    const employee = (await this.getEmployeeById(id))!;
    return { employee, inviteUrl };
  }
}

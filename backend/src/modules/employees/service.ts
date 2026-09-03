import { bmoniClient } from '../../bmoni/client.js';
import { db } from '../../db/index.js';
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
  static listEmployees(): EmployeeRecord[] {
    return db.prepare('SELECT * FROM employees ORDER BY created_at DESC').all() as EmployeeRecord[];
  }

  static getEmployeeById(id: string): EmployeeRecord | undefined {
    return db.prepare('SELECT * FROM employees WHERE id = ?').get(id) as EmployeeRecord | undefined;
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

    // 2. Insert into SQLite
    db.prepare(`
      INSERT INTO employees (id, partner_id, first_name, last_name, email, phone_number, country, target_currency, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      env.BMONI_PARTNER_ID,
      data.firstName,
      data.lastName,
      data.email,
      data.phoneNumber ?? null,
      data.country,
      data.targetCurrency,
      'INVITED'
    );

    const employee = this.getEmployeeById(id)!;
    return { employee, inviteUrl };
  }
}

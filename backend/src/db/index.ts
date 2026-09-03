import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from '../config/env.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// env.DATABASE_URL now holds a Postgres connection string (Supabase Session
// pooler URI), not a local SQLite file path.
export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // Supabase requires TLS; adjust if you pin a CA instead
});

export async function initDatabase(): Promise<void> {
  const schemaPath = path.join(__dirname, 'schema.sql');
  let schemaSql = '';
  if (fs.existsSync(schemaPath)) {
    schemaSql = fs.readFileSync(schemaPath, 'utf-8');
  } else {
    const srcSchemaPath = path.resolve(__dirname, '../../src/db/schema.sql');
    if (fs.existsSync(srcSchemaPath)) {
      schemaSql = fs.readFileSync(srcSchemaPath, 'utf-8');
    }
  }

  if (schemaSql) {
    // pg's simple query protocol supports multiple ;-separated statements
    // in one call as long as none of them are parameterized — schema.sql
    // qualifies, since it's plain DDL with no $1-style placeholders.
    await pool.query(schemaSql);
  }
  await seedDemoDataIfNeeded();
}

async function seedDemoDataIfNeeded(): Promise<void> {
  try {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM employees');
    const employeeCount = rows[0].count as number;

    if (employeeCount === 0) {
      // Seed pre-verified BMONI sandbox personas per spec:
      // Employee 1: Bunch Dillon (Nigeria, BVN 99999999999)
      // Employee 2: Samson Jabo (Mexico/Nigeria alt, BVN/NIN 22222222222)
      await pool.query(
        `INSERT INTO employees
           (id, bmoni_user_id, partner_id, first_name, last_name, email, phone_number, country, target_currency, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          'emp_bunch_dillon',
          'usr_bmoni_dillon_ngn',
          env.BMONI_PARTNER_ID,
          'Bunch',
          'Dillon',
          'bunch.dillon@example.ng',
          '+2348011112222',
          'NG',
          'NGN',
          'LINKED',
        ]
      );

      await pool.query(
        `INSERT INTO employees
           (id, bmoni_user_id, partner_id, first_name, last_name, email, phone_number, country, target_currency, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          'emp_samson_jabo',
          'usr_bmoni_samson_mxn',
          env.BMONI_PARTNER_ID,
          'Samson',
          'Jabo',
          'samson.jabo@example.mx',
          '+525512345678',
          'MX',
          'MXN',
          'LINKED',
        ]
      );

      // Seed default Money Missions
      await pool.query(
        `INSERT INTO money_missions
           (id, title, description, rule_type, condition_json, action_json, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          'mission_emergency_sweep',
          '20% Emergency Fund Auto-Sweep',
          'Automatically route 20% of international USD disbursements into high-yield NGN savings.',
          'AUTO_SWEEP',
          JSON.stringify({ trigger: 'DEPOSIT_RECEIVED', currency: 'USD' }),
          JSON.stringify({ percentage: 20, destinationCurrency: 'NGN' }),
          true,
        ]
      );

      await pool.query(
        `INSERT INTO money_missions
           (id, title, description, rule_type, condition_json, action_json, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          'mission_card_cap',
          'Contractor Card Monthly Cap',
          'Enforce a strict $500/month spending limit on virtual cards for team contractors.',
          'SPEND_CAP',
          JSON.stringify({ role: 'CONTRACTOR' }),
          JSON.stringify({ monthlyLimitUsdMinor: 50000 }),
          true,
        ]
      );
    }
  } catch (err) {
    console.warn('[DB] Seeding note:', err);
  }
}
import Database, { type Database as DatabaseInstance } from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from '../config/env.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Initialize SQLite database
export const db: DatabaseInstance = new Database(env.DATABASE_URL);

// Enable WAL mode for high performance concurrent reads/writes
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

export function initDatabase(): void {
  const schemaPath = path.join(__dirname, 'schema.sql');
  // In built dist, schema.sql is alongside or in src
  let schemaSql = '';
  if (fs.existsSync(schemaPath)) {
    schemaSql = fs.readFileSync(schemaPath, 'utf-8');
  } else {
    // Fallback to src directory when running compiled dist
    const srcSchemaPath = path.resolve(__dirname, '../../src/db/schema.sql');
    if (fs.existsSync(srcSchemaPath)) {
      schemaSql = fs.readFileSync(srcSchemaPath, 'utf-8');
    }
  }

  if (schemaSql) {
    db.exec(schemaSql);
  }
  seedDemoDataIfNeeded();
}

function seedDemoDataIfNeeded(): void {
  try {
    const employeeCount = (db.prepare('SELECT COUNT(*) as count FROM employees').get() as { count: number }).count;
    
    if (employeeCount === 0) {
      // Seed pre-verified BMONI sandbox personas per spec:
      // Employee 1: Bunch Dillon (Nigeria, BVN 99999999999)
      // Employee 2: Samson Jabo (Mexico/Nigeria alt, BVN/NIN 22222222222)
      const insertEmployee = db.prepare(`
        INSERT INTO employees (id, bmoni_user_id, partner_id, first_name, last_name, email, phone_number, country, target_currency, status)
        VALUES (@id, @bmoni_user_id, @partner_id, @first_name, @last_name, @email, @phone_number, @country, @target_currency, @status)
      `);

      insertEmployee.run({
        id: 'emp_bunch_dillon',
        bmoni_user_id: 'usr_bmoni_dillon_ngn',
        partner_id: env.BMONI_PARTNER_ID,
        first_name: 'Bunch',
        last_name: 'Dillon',
        email: 'bunch.dillon@example.ng',
        phone_number: '+2348011112222',
        country: 'NG',
        target_currency: 'NGN',
        status: 'LINKED',
      });

      insertEmployee.run({
        id: 'emp_samson_jabo',
        bmoni_user_id: 'usr_bmoni_samson_mxn',
        partner_id: env.BMONI_PARTNER_ID,
        first_name: 'Samson',
        last_name: 'Jabo',
        email: 'samson.jabo@example.mx',
        phone_number: '+525512345678',
        country: 'MX',
        target_currency: 'MXN',
        status: 'LINKED',
      });

      // Seed default Money Missions
      const insertMission = db.prepare(`
        INSERT INTO money_missions (id, title, description, rule_type, condition_json, action_json, is_active)
        VALUES (@id, @title, @description, @rule_type, @condition_json, @action_json, @is_active)
      `);

      insertMission.run({
        id: 'mission_emergency_sweep',
        title: '20% Emergency Fund Auto-Sweep',
        description: 'Automatically route 20% of international USD disbursements into high-yield NGN savings.',
        rule_type: 'AUTO_SWEEP',
        condition_json: JSON.stringify({ trigger: 'DEPOSIT_RECEIVED', currency: 'USD' }),
        action_json: JSON.stringify({ percentage: 20, destinationCurrency: 'NGN' }),
        is_active: 1,
      });

      insertMission.run({
        id: 'mission_card_cap',
        title: 'Contractor Card Monthly Cap',
        description: 'Enforce a strict $500/month spending limit on virtual cards for team contractors.',
        rule_type: 'SPEND_CAP',
        condition_json: JSON.stringify({ role: 'CONTRACTOR' }),
        action_json: JSON.stringify({ monthlyLimitUsdMinor: 50000 }),
        is_active: 1,
      });
    }
  } catch (err) {
    console.warn('[DB] Seeding note:', err);
  }
}

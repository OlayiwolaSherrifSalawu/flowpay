import { pool } from '../../db/index.js';

export interface MoneyMission {
  id: string;
  title: string;
  description: string;
  rule_type: string;
  condition_json: string | Record<string, unknown>;
  action_json: string | Record<string, unknown>;
  is_active: boolean | number;
  created_at: string;
  updated_at: string;
}

export class MoneyMissionService {
  static async listMissions(): Promise<MoneyMission[]> {
    try {
      const { rows } = await pool.query('SELECT * FROM money_missions ORDER BY created_at DESC');
      return rows as MoneyMission[];
    } catch (err) {
      console.warn('[MoneyMissionService] listMissions error:', err);
      return [];
    }
  }

  static async createMission(data: {
    title: string;
    description: string;
    ruleType: string;
    condition: Record<string, unknown>;
    action: Record<string, unknown>;
  }): Promise<MoneyMission> {
    const id = `mission_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    
    await pool.query(
      `INSERT INTO money_missions (id, title, description, rule_type, condition_json, action_json, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, true)`,
      [
        id,
        data.title,
        data.description,
        data.ruleType,
        JSON.stringify(data.condition),
        JSON.stringify(data.action),
      ]
    );

    const { rows } = await pool.query('SELECT * FROM money_missions WHERE id = $1', [id]);
    return rows[0] as MoneyMission;
  }

  static async toggleMission(id: string): Promise<{ is_active: boolean }> {
    const { rows } = await pool.query('SELECT is_active FROM money_missions WHERE id = $1', [id]);
    const current = rows[0]?.is_active;
    const nextState = !(current === true || current === 1);

    await pool.query(
      'UPDATE money_missions SET is_active = $1, updated_at = now() WHERE id = $2',
      [nextState, id]
    );

    return { is_active: nextState };
  }
}

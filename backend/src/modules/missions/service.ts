import { db } from '../../db/index.js';

export interface MoneyMission {
  id: string;
  title: string;
  description: string;
  rule_type: string;
  condition_json: string;
  action_json: string;
  is_active: number;
  created_at: string;
  updated_at: string;
}

export class MoneyMissionService {
  static listMissions(): MoneyMission[] {
    return db.prepare('SELECT * FROM money_missions ORDER BY created_at DESC').all() as MoneyMission[];
  }

  static createMission(data: {
    title: string;
    description: string;
    ruleType: string;
    condition: Record<string, unknown>;
    action: Record<string, unknown>;
  }): MoneyMission {
    const id = `mission_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    
    db.prepare(`
      INSERT INTO money_missions (id, title, description, rule_type, condition_json, action_json, is_active)
      VALUES (?, ?, ?, ?, ?, ?, 1)
    `).run(
      id,
      data.title,
      data.description,
      data.ruleType,
      JSON.stringify(data.condition),
      JSON.stringify(data.action)
    );

    return db.prepare('SELECT * FROM money_missions WHERE id = ?').get(id) as MoneyMission;
  }

  static toggleMission(id: string): { is_active: number } {
    const current = db.prepare('SELECT is_active FROM money_missions WHERE id = ?').get(id) as { is_active: number } | undefined;
    const nextState = current?.is_active === 1 ? 0 : 1;

    db.prepare('UPDATE money_missions SET is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(
      nextState,
      id
    );

    return { is_active: nextState };
  }
}

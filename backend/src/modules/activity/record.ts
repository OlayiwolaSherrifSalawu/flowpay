import { isPostgresDb, prisma } from '../../db/index.js';
import { recordInMemoryActivity } from '../../routes/activity.routes.js';

export const newId = (prefix: string) => `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;

/** Appends an activity entry (in-memory + Postgres when connected). Never throws. */
export async function recordActivity(entry: {
  id?: string;
  category?: 'PERSONAL' | 'BUSINESS' | 'SYSTEM' | 'AI';
  action: string;
  actor: string;
  details: Record<string, unknown>;
}): Promise<string> {
  const record = {
    id: entry.id ?? newId('act'),
    category: entry.category ?? 'PERSONAL',
    action: entry.action,
    actor: entry.actor,
    detailsJson: entry.details,
    createdAt: new Date().toISOString(),
  };
  recordInMemoryActivity(record);
  if (isPostgresDb()) {
    try {
      await prisma.auditActivity.create({
        data: { id: record.id, category: record.category, action: record.action, actor: record.actor, detailsJson: record.detailsJson as any },
      });
    } catch (dbErr: any) {
      console.warn('[Activity] persistence failed:', dbErr.message);
    }
  }
  return record.id;
}

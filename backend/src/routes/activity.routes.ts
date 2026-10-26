import { authedUserId } from '../auth/session.js';
import { Router } from 'express';
import { prisma, isPostgresDb } from '../db/index.js';

export const activityRouter = Router();

// In-memory activity log (also the fallback when Postgres is not connected). Starts empty:
// only real events are ever recorded.
const inMemoryActivities: any[] = [];

/** Read-only view for tests and diagnostics. */
export function listInMemoryActivities(): readonly any[] {
  return inMemoryActivities;
}

export function recordInMemoryActivity(activity: any): void {
  inMemoryActivities.unshift(activity);
  if (inMemoryActivities.length > 100) {
    inMemoryActivities.pop();
  }
}

import { parsePaginationParams, paginateArray } from '../core/pagination.js';

// GET /api/activity?category=PERSONAL&page=1&limit=10
activityRouter.get('/', async (req, res, next) => {
  try {
    const category = req.query.category as string | undefined;
    const search = req.query.search as string | undefined;
    const userId = authedUserId(req);

    // Every event is recorded once per involved user (sender, recipient, employer…)
    // with that user as `actor`, so a user's feed is exactly their own rows.
    const categoryFilter = category ? { category: category.toUpperCase() } : {};
    let rows: any[] = [];
    let fromDb = false;
    if (isPostgresDb()) {
      try {
        rows = await prisma.auditActivity.findMany({
          where: { actor: userId, ...categoryFilter },
          orderBy: { createdAt: 'desc' },
          take: 500,
        });
        fromDb = true;
      } catch (dbErr) {
        console.warn('[Activity] DB read failed, using in-memory store fallback:', dbErr);
      }
    }
    if (!fromDb) {
      rows = inMemoryActivities.filter(
        (a) => a.actor === userId && (!category || a.category?.toUpperCase() === category.toUpperCase())
      );
    }

    if (search) {
      const q = search.toLowerCase();
      rows = rows.filter(
        (a) =>
          a.action?.toLowerCase().includes(q) ||
          a.actor?.toLowerCase().includes(q) ||
          JSON.stringify(a.detailsJson ?? {}).toLowerCase().includes(q)
      );
    }

    if (req.query.page !== undefined || req.query.limit !== undefined) {
      const { page, limit } = parsePaginationParams(req.query, 10);
      const paginated = paginateArray(rows, page, limit);
      return res.json({ success: true, data: paginated });
    }

    res.json({ success: true, data: rows });
  } catch (err) {
    next(err);
  }
});

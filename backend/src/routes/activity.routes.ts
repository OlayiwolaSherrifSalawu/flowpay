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
    const userId = (req.query.userId as string | undefined) || (req.headers['x-user-id'] as string | undefined);

    let rows: any[] = [];
    if (isPostgresDb()) {
      try {
        rows = await prisma.auditActivity.findMany({
          where: category ? { category: category.toUpperCase() } : undefined,
          orderBy: { createdAt: 'desc' },
          take: 100,
        });
      } catch (dbErr) {
        console.warn('[Activity] DB read failed, using in-memory store fallback:', dbErr);
      }
    }

    if (rows.length === 0) {
      let list = inMemoryActivities;
      if (category) {
        list = list.filter((a) => a.category?.toUpperCase() === category.toUpperCase());
      }
      rows = list;
    }

    if (userId) {
      const userLower = userId.toLowerCase().trim();
      rows = rows.filter((a) => {
        const actor = (a.actor || '').toLowerCase().trim();
        const details = a.detailsJson ?? {};
        const recipient = (details.recipient || '').toLowerCase().trim();
        const recipientUserId = (details.recipientUserId || '').toLowerCase().trim();
        const sender = (details.sender || '').toLowerCase().trim();
        const counterparty = (details.counterparty || '').toLowerCase().trim();
        const targetUserId = (details.userId || '').toLowerCase().trim();

        const action = (a.action || '').toUpperCase();

        if (action === 'TRANSFER_RECEIVED') {
          return actor === userLower || recipient === userLower || recipientUserId === userLower;
        }

        if (action === 'TRANSFER_COMPLETED' || action === 'TRANSFER_SENT') {
          return actor === userLower || sender === userLower;
        }

        // Direct ownership or participation
        if (actor === userLower || targetUserId === userLower) {
          return true;
        }

        // If actor is system, only include if user is explicitly involved
        if (actor === 'system') {
          return (
            recipient === userLower ||
            recipientUserId === userLower ||
            sender === userLower ||
            counterparty === userLower ||
            targetUserId === userLower
          );
        }

        return false;
      });
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

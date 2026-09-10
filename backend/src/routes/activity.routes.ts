import { Router } from 'express';
import { prisma, isPostgresDb } from '../db/index.js';

export const activityRouter = Router();

// In-memory fallback activities for sandbox / offline / when DB is disconnected
const inMemoryActivities: any[] = [
  {
    id: 'act_seed_01',
    category: 'PERSONAL',
    action: 'TRANSFER_COMPLETED',
    actor: 'usr_flowpay_sandbox_master',
    detailsJson: {
      transferId: 'prop_mock_01',
      recipient: 'Bunch Dillon',
      amount: '250.00',
      currency: 'USD',
      status: 'COMPLETED',
    },
    createdAt: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 'act_seed_02',
    category: 'SYSTEM',
    action: 'WALLET_PROVISIONED',
    actor: 'BMONI_SYSTEM',
    detailsJson: {
      walletId: 'sw_usdb_sandbox_01',
      currency: 'USD',
      network: 'Base Sepolia',
    },
    createdAt: new Date(Date.now() - 7200000).toISOString(),
  },
  {
    id: 'act_seed_03',
    category: 'BUSINESS',
    action: 'PAYROLL_PROPOSAL_CREATED',
    actor: 'usr_flowpay_sandbox_master',
    detailsJson: {
      runId: 'payrun_seed_01',
      employeeCount: 2,
      totalUsdFormatted: '$4,200.00',
    },
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
];

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

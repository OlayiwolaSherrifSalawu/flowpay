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

// GET /api/activity
activityRouter.get('/', async (req, res, next) => {
  try {
    const category = req.query.category as string | undefined;

    if (isPostgresDb()) {
      try {
        const rows = await prisma.auditActivity.findMany({
          where: category ? { category: category.toUpperCase() } : undefined,
          orderBy: { createdAt: 'desc' },
          take: 50,
        });
        return res.json({ success: true, data: rows });
      } catch (dbErr) {
        console.warn('[Activity] DB read failed, using in-memory store fallback:', dbErr);
      }
    }

    let list = inMemoryActivities;
    if (category) {
      list = list.filter((a) => a.category.toUpperCase() === category.toUpperCase());
    }

    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

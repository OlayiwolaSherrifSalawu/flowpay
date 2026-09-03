import { Router } from 'express';
import { prisma } from '../db/index.js';

export const activityRouter = Router();

// GET /api/activity
activityRouter.get('/', async (req, res, next) => {
  try {
    const category = req.query.category as string | undefined;

    const rows = await prisma.auditActivity.findMany({
      where: category ? { category: category.toUpperCase() } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    res.json({ success: true, data: rows });
  } catch (err) {
    next(err);
  }
});

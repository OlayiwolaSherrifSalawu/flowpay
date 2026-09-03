import { Router } from 'express';
import { db } from '../db/index.js';

export const activityRouter = Router();

// GET /api/activity
activityRouter.get('/', (req, res, next) => {
  try {
    const category = req.query.category as string | undefined;
    let query = 'SELECT * FROM audit_activity';
    const params: unknown[] = [];

    if (category) {
      query += ' WHERE category = ?';
      params.push(category.toUpperCase());
    }

    query += ' ORDER BY created_at DESC LIMIT 50';
    const list = db.prepare(query).all(...params);

    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

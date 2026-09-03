import { Router } from 'express';
import { pool } from '../db/index.js';

export const activityRouter = Router();

// GET /api/activity
activityRouter.get('/', async (req, res, next) => {
  try {
    const category = req.query.category as string | undefined;
    let query = 'SELECT * FROM audit_activity';
    const params: unknown[] = [];

    if (category) {
      query += ' WHERE category = $1';
      params.push(category.toUpperCase());
    }

    query += ' ORDER BY created_at DESC LIMIT 50';
    const { rows } = await pool.query(query, params);

    res.json({ success: true, data: rows });
  } catch (err) {
    next(err);
  }
});

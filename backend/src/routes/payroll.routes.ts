import { Router } from 'express';
import { db } from '../db/index.js';
import { PayrollOrchestrationService } from '../modules/payroll/service.js';

export const payrollRouter = Router();

// GET /api/payroll/preview
payrollRouter.get('/preview', (req, res, next) => {
  try {
    const preview = PayrollOrchestrationService.getPreview();
    res.json({ success: true, data: preview });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/execute
payrollRouter.post('/execute', async (req, res, next) => {
  try {
    const employerUserId = req.body.employerUserId || 'usr_flowpay_sandbox_master';
    const sourceSmartWalletId = req.body.sourceSmartWalletId || 'sw_usdb_sandbox_01';
    const summary = await PayrollOrchestrationService.executePayroll(
      employerUserId,
      sourceSmartWalletId,
      req.body.allocations
    );
    res.json({ success: true, data: summary });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/runs
payrollRouter.get('/runs', (req, res, next) => {
  try {
    const runs = db.prepare('SELECT * FROM payroll_runs ORDER BY created_at DESC LIMIT 20').all();
    res.json({ success: true, data: runs });
  } catch (err) {
    next(err);
  }
});

import { Router } from 'express';
import { prisma } from '../db/index.js';
import { PayrollOrchestrationService } from '../modules/payroll/service.js';

export const payrollRouter = Router();

// GET /api/payroll/preview
payrollRouter.get('/preview', async (req, res, next) => {
  try {
    const preview = await PayrollOrchestrationService.getPreview();
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
      req.body.allocations,
      req.body.signatures
    );
    res.json({ success: true, data: summary });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/proposals/:proposalId/retry
payrollRouter.post('/proposals/:proposalId/retry', async (req, res, next) => {
  try {
    const employerUserId = req.body.employerUserId || 'usr_flowpay_sandbox_master';
    const { proposalId } = req.params;
    const { employeeId } = req.body;
    const result = await PayrollOrchestrationService.retryProposal(
      employerUserId,
      proposalId,
      employeeId
    );
    res.json({ success: result.success, data: result.item, message: result.message });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/runs
payrollRouter.get('/runs', async (req, res, next) => {
  try {
    const runs = await prisma.payrollRun.findMany({
      include: { items: true },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    res.json({ success: true, data: runs });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/runs/:runId
payrollRouter.get('/runs/:runId', async (req, res, next) => {
  try {
    const run = await prisma.payrollRun.findUnique({
      where: { id: req.params.runId },
      include: { items: true },
    });
    if (!run) {
      return res.status(404).json({ success: false, error: 'Payroll run not found' });
    }
    res.json({ success: true, data: run });
  } catch (err) {
    next(err);
  }
});

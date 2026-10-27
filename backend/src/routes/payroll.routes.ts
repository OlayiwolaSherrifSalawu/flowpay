import { authedUserId } from '../auth/session.js';
import { Router, type Request } from 'express';
import { InvalidRequestError } from '../core/errors.js';
import { paginateArray, parsePaginationParams } from '../core/pagination.js';
import { PayrollGuaranteeService } from '../modules/payroll/guarantee_service.js';
import { PayrollOrchestrationService } from '../modules/payroll/service.js';

export const payrollRouter = Router();

// Identity comes only from the verified session token (see auth/session.ts).
const requestUserId = (req: Request) => authedUserId(req);

// GET /api/payroll/preview — live quotes + the unsigned transactions to approve.
payrollRouter.get('/preview', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollOrchestrationService.getPreview(requestUserId(req), { includeRecentlyPaid: req.query.includeRecentlyPaid === 'true' }) });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/execute { runId, signed: { [proposalId]: signedXdr } }
payrollRouter.post('/execute', async (req, res, next) => {
  try {
    const { runId, signed } = req.body ?? {};
    if (typeof runId !== 'string' || !signed || typeof signed !== 'object') throw new InvalidRequestError('runId and signed are required');
    res.json({ success: true, data: await PayrollOrchestrationService.executePayroll(requestUserId(req), runId, signed) });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/runs
payrollRouter.get('/runs', async (req, res, next) => {
  try {
    const runs = await PayrollOrchestrationService.listRuns(requestUserId(req));
    if (req.query.page !== undefined || req.query.limit !== undefined) {
      const { page, limit } = parsePaginationParams(req.query, 10);
      return res.json({ success: true, data: paginateArray(runs, page, limit) });
    }
    res.json({ success: true, data: runs });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/runs/:id
payrollRouter.get('/runs/:id', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollOrchestrationService.getRun(requestUserId(req), req.params.id) });
  } catch (err) {
    next(err);
  }
});

// ── Payday guarantee (Soroban PayrollVault) ───────────────────────────────────

function signedBody(req: Request): { proposalId: string; signedXdr: string } {
  const { proposalId, signedXdr } = req.body ?? {};
  if (typeof proposalId !== 'string' || typeof signedXdr !== 'string') throw new InvalidRequestError('proposalId and signedXdr are required');
  return { proposalId, signedXdr };
}

function payrollIdParam(req: Request): number {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) throw new InvalidRequestError('Invalid guarantee id');
  return id;
}

// POST /api/payroll/guarantees/propose { unlockAt } → unsigned `fund` transaction
payrollRouter.post('/guarantees/propose', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollGuaranteeService.propose(requestUserId(req), req.body ?? {}) });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/guarantees/execute { proposalId, signedXdr }
payrollRouter.post('/guarantees/execute', async (req, res, next) => {
  try {
    const { proposalId, signedXdr } = signedBody(req);
    res.json({ success: true, data: await PayrollGuaranteeService.execute(requestUserId(req), proposalId, signedXdr) });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/guarantees — the employer's guarantees with on-chain status
payrollRouter.get('/guarantees', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollGuaranteeService.listForEmployer(requestUserId(req)) });
  } catch (err) {
    next(err);
  }
});

// GET /api/payroll/guarantees/mine — pay reserved for the signed-in employee
payrollRouter.get('/guarantees/mine', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollGuaranteeService.listForEmployee(requestUserId(req)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/guarantees/claim/execute { proposalId, signedXdr }
payrollRouter.post('/guarantees/claim/execute', async (req, res, next) => {
  try {
    const { proposalId, signedXdr } = signedBody(req);
    res.json({ success: true, data: await PayrollGuaranteeService.executeClaim(requestUserId(req), proposalId, signedXdr) });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/guarantees/:id/claim → unsigned `claim` for the employee to sign
payrollRouter.post('/guarantees/:id/claim', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollGuaranteeService.proposeClaim(requestUserId(req), payrollIdParam(req)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/payroll/guarantees/:id/release — pay every unlocked, unpaid salary now
payrollRouter.post('/guarantees/:id/release', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollGuaranteeService.releaseAll(requestUserId(req), payrollIdParam(req)) });
  } catch (err) {
    next(err);
  }
});

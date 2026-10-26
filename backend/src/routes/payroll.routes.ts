import { Router, type Request } from 'express';
import { InvalidRequestError } from '../core/errors.js';
import { paginateArray, parsePaginationParams } from '../core/pagination.js';
import { PayrollOrchestrationService } from '../modules/payroll/service.js';

export const payrollRouter = Router();

// TODO(M8): replace header-based identity with authenticated sessions.
function requestUserId(req: Request): string {
  const userId = (req.headers['x-user-id'] as string) || (req.query.userId as string) || (req.body?.employerUserId as string) || (req.body?.userId as string);
  if (!userId) throw new InvalidRequestError('userId is required.');
  return userId;
}

// GET /api/payroll/preview — live quotes + the unsigned transactions to approve.
payrollRouter.get('/preview', async (req, res, next) => {
  try {
    res.json({ success: true, data: await PayrollOrchestrationService.getPreview(requestUserId(req)) });
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

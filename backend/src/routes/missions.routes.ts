import { authedUserId } from '../auth/session.js';
import { Router, type Request } from 'express';
import { InvalidRequestError, StellarSubmitTimeoutError } from '../core/errors.js';
import { MoneyMissionService } from '../modules/missions/service.js';
import { explorerTxUrl } from '../stellar/config.js';

export const missionsRouter = Router();

// Identity comes only from the verified session token (see auth/session.ts).
const requestUserId = (req: Request) => authedUserId(req);

// GET /api/missions — this user's missions only.
missionsRouter.get('/', async (req, res, next) => {
  try {
    res.json({ success: true, data: await MoneyMissionService.listMissions(requestUserId(req)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions/propose { intent } → saved rule + first run's unsigned transaction.
missionsRouter.post('/propose', async (req, res, next) => {
  try {
    if (!req.body?.intent) throw new InvalidRequestError('Mission intent is required');
    res.json({ success: true, data: await MoneyMissionService.proposeMission(requestUserId(req), req.body.intent) });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions/:id/prepare → unsigned transaction for a new run.
missionsRouter.post('/:id/prepare', async (req, res, next) => {
  try {
    res.json({ success: true, data: await MoneyMissionService.prepareRun(req.params.id, requestUserId(req), req.body?.accountId) });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions/:id/execute { proposalId?, signedXdr? } — activate and/or submit a signed run.
missionsRouter.post('/:id/execute', async (req, res, next) => {
  try {
    const data = await MoneyMissionService.executeMission({
      missionId: req.params.id,
      userId: requestUserId(req),
      proposalId: req.body?.proposalId,
      signedXdr: req.body?.signedXdr,
    });
    res.json({ success: true, data });
  } catch (err) {
    if (err instanceof StellarSubmitTimeoutError) {
      return res.status(202).json({
        success: false,
        code: err.code,
        message: 'Submitted; waiting for the Stellar network to confirm.',
        data: { status: 'PENDING', transactionHash: err.hash, explorerUrl: explorerTxUrl(err.hash) },
      });
    }
    next(err);
  }
});

// POST /api/missions — save a rule without running it.
missionsRouter.post('/', async (req, res, next) => {
  try {
    res.json({ success: true, data: await MoneyMissionService.createMission(requestUserId(req), req.body) });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/missions/:id/toggle
missionsRouter.patch('/:id/toggle', async (req, res, next) => {
  try {
    res.json({ success: true, data: await MoneyMissionService.toggleMission(req.params.id, requestUserId(req)) });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/missions/:id
missionsRouter.delete('/:id', async (req, res, next) => {
  try {
    res.json({ success: true, data: { deleted: await MoneyMissionService.deleteMission(req.params.id, requestUserId(req)) } });
  } catch (err) {
    next(err);
  }
});

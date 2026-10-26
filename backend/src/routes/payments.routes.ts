import { authedUserId } from '../auth/session.js';
import { Router, type Request } from 'express';
import { InvalidRequestError, StellarSubmitTimeoutError } from '../core/errors.js';
import { BatchPaymentService } from '../modules/payments/batch_service.js';
import { explorerTxUrl } from '../stellar/config.js';

/** Atomic multi-payment transactions (AI plans, FX conversion, locked savings). */
export const paymentsRouter = Router();

// Identity comes only from the verified session token (see auth/session.ts).
const requestUserId = (req: Request) => authedUserId(req);

// POST /api/payments/batch/propose { legs, memo?, purpose?, reference?, accountId? }
paymentsRouter.post('/batch/propose', async (req, res, next) => {
  try {
    const { legs, memo, purpose, reference, accountId } = req.body ?? {};
    const data = await BatchPaymentService.propose({
      userId: requestUserId(req),
      accountId,
      legs,
      memo,
      context: { purpose: typeof purpose === 'string' ? purpose : 'PAYMENT', reference },
    });
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
});

// POST /api/payments/batch/execute { proposalId, signedXdr }
paymentsRouter.post('/batch/execute', async (req, res, next) => {
  try {
    const { proposalId, signedXdr } = req.body ?? {};
    if (typeof proposalId !== 'string' || typeof signedXdr !== 'string') throw new InvalidRequestError('proposalId and signedXdr are required');
    res.json({ success: true, data: await BatchPaymentService.execute({ userId: requestUserId(req), proposalId, signedXdr }) });
  } catch (err) {
    if (err instanceof StellarSubmitTimeoutError) {
      return res.status(202).json({
        success: false,
        code: err.code,
        message: 'Submitted; waiting for the Stellar network to confirm.',
        data: { proposalId: req.body?.proposalId, status: 'PENDING', transactionHash: err.hash, explorerUrl: explorerTxUrl(err.hash) },
      });
    }
    next(err);
  }
});

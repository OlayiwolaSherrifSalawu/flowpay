import { Router, type Request } from 'express';
import { InvalidRequestError, StellarSubmitTimeoutError } from '../core/errors.js';
import { TransferService } from '../modules/transfers/service.js';
import { explorerTxUrl } from '../stellar/config.js';
import { resolveRecipient } from '../stellar/directory.js';

export const transfersRouter = Router();

// TODO(M7): replace header-based identity with authenticated sessions.
function requestUserId(req: Request): string {
  const userId = (req.body?.userId as string) || (req.headers['x-user-id'] as string);
  if (!userId) throw new InvalidRequestError('userId is required.');
  return userId;
}

// POST /api/transfers/interpret — natural language → structured intent (nothing moves).
transfersRouter.post('/interpret', async (req, res, next) => {
  try {
    const { prompt } = req.body;
    if (!prompt || typeof prompt !== 'string') throw new InvalidRequestError('prompt is required');
    const intent = await TransferService.interpret(prompt);
    res.json({ success: true, data: { intent, requiresApproval: true } });
  } catch (err) {
    next(err);
  }
});

// GET /api/transfers/recipient?query=... — strict recipient lookup for the review screen.
transfersRouter.get('/recipient', async (req, res, next) => {
  try {
    const r = await resolveRecipient(String(req.query.query ?? ''));
    res.json({ success: true, data: { accountId: r.accountId, displayName: r.displayName, source: r.source, isFlowPayUser: !!r.userId } });
  } catch (err) {
    next(err);
  }
});

// POST /api/transfers/inspect-balances { intent, accountId? } — real balances + live quotes.
transfersRouter.post('/inspect-balances', async (req, res, next) => {
  try {
    const data = await TransferService.inspectBalances({
      userId: requestUserId(req),
      accountId: req.body?.accountId,
      intent: req.body?.intent,
    });
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
});

// POST /api/transfers/propose { intent, fundingOption, accountId? } → unsigned Stellar XDR.
transfersRouter.post('/propose', async (req, res, next) => {
  try {
    const { intent, fundingOption, accountId } = req.body ?? {};
    if (!intent || !fundingOption) throw new InvalidRequestError('intent and fundingOption are required');
    const proposal = await TransferService.createProposal({ userId: requestUserId(req), accountId, intent, fundingOption });
    res.json({ success: true, data: proposal });
  } catch (err) {
    next(err);
  }
});

// POST /api/transfers/execute { proposalId, signedXdr } — submit the device-signed transaction.
transfersRouter.post('/execute', async (req, res, next) => {
  try {
    const { proposalId } = req.body ?? {};
    const signedXdr = req.body?.signedXdr ?? req.body?.signature;
    if (typeof proposalId !== 'string' || typeof signedXdr !== 'string') {
      throw new InvalidRequestError('proposalId and signedXdr are required');
    }
    const result = await TransferService.executeTransfer({ userId: requestUserId(req), proposalId, signedXdr });
    res.json({ success: true, data: result });
  } catch (err) {
    if (err instanceof StellarSubmitTimeoutError) {
      return res.status(202).json({
        success: false,
        code: err.code,
        message: 'Your transfer was submitted but the network has not confirmed it yet.',
        data: { proposalId: req.body?.proposalId, status: 'PENDING', transactionHash: err.hash, explorerUrl: explorerTxUrl(err.hash) },
      });
    }
    next(err);
  }
});

// GET /api/transfers/rates — indicative units per 1 USD from live Stellar liquidity.
transfersRouter.get('/rates', async (_req, res, next) => {
  try {
    res.json({ success: true, data: await TransferService.getExchangeRates() });
  } catch (err) {
    next(err);
  }
});

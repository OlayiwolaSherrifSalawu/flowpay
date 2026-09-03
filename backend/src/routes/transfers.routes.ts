import { Router } from 'express';
import { bmoniClient } from '../bmoni/client.js';

export const transfersRouter = Router();

// POST /api/transfers/proposals
transfersRouter.post('/proposals', async (req, res, next) => {
  try {
    const proposal = await bmoniClient.createTransferProposal(req.body);
    res.json({ success: true, data: proposal });
  } catch (err) {
    next(err);
  }
});

// GET /api/transfers/proposals/:proposalId/sign-payload
transfersRouter.get('/proposals/:proposalId/sign-payload', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const payload = await bmoniClient.getProposalSignPayload({
      userId,
      proposalId: req.params.proposalId,
    });
    res.json({ success: true, data: payload });
  } catch (err) {
    next(err);
  }
});

// POST /api/transfers/proposals/:proposalId/sign
transfersRouter.post('/proposals/:proposalId/sign', async (req, res, next) => {
  try {
    const userId = (req.body.userId as string) || 'usr_flowpay_sandbox_master';
    const result = await bmoniClient.signProposal({
      userId,
      proposalId: req.params.proposalId,
      signature: req.body.signature,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

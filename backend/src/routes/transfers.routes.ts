import { Router } from 'express';
import { bmoniClient } from '../bmoni/client.js';
import { TransferService } from '../modules/transfers/service.js';
import {
  BalanceInspectionInputSchema,
  TransferExecuteSchema,
  TransferIntentSchema,
  TransferProposeSchema,
  TransferValidator,
} from '../modules/transfers/validator.js';

export const transfersRouter = Router();

// POST /api/transfers/interpret
// Step 1: Natural Language Transfer Intent Extraction
transfersRouter.post('/interpret', async (req, res, next) => {
  try {
    const { prompt } = req.body;
    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({
        success: false,
        message: TransferValidator.formatError('INVALID_RECIPIENT', 'Natural language prompt is required'),
      });
    }

    const intent = await TransferService.interpret(prompt);
    res.json({
      success: true,
      data: {
        intent,
        requiresApproval: true,
      },
    });
  } catch (err: any) {
    next(err);
  }
});

// POST /api/transfers/inspect-balances
// Step 2: Balance-Aware Wallet Inspection & Cross-Currency Routing
transfersRouter.post('/inspect-balances', async (req, res, next) => {
  try {
    const parseResult = BalanceInspectionInputSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        message: parseResult.error.issues.map((i) => i.message).join('; '),
      });
    }

    const { intent, wallets } = parseResult.data;
    const inspection = TransferService.inspectBalances(intent as any, wallets as any);

    res.json({
      success: true,
      data: inspection,
    });
  } catch (err: any) {
    next(err);
  }
});

// POST /api/transfers/propose
// Step 3: BMONI Transfer Proposal & Signing Payload Generation
transfersRouter.post('/propose', async (req, res, next) => {
  try {
    const { userId, intent, fundingOption } = req.body;
    if (!intent || !fundingOption) {
      return res.status(400).json({
        success: false,
        message: 'intent and fundingOption are required to create a transfer proposal',
      });
    }

    const proposal = await TransferService.createProposal({
      userId: userId || 'usr_flowpay_sandbox_master',
      intent,
      fundingOption,
    });

    res.json({
      success: true,
      data: proposal,
    });
  } catch (err: any) {
    next(err);
  }
});

// POST /api/transfers/execute
// Step 4: Submit on-device B-Key signature, verify BMONI execution, log to Activity
transfersRouter.post('/execute', async (req, res, next) => {
  try {
    const parseResult = TransferExecuteSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        success: false,
        message: parseResult.error.issues.map((i) => i.message).join('; '),
      });
    }

    const { userId, proposalId, signature } = parseResult.data;
    const { proposalPayload } = req.body;

    const result = await TransferService.executeTransfer({
      userId,
      proposalId,
      signature,
      proposalPayload,
    });

    res.json({
      success: true,
      data: result,
    });
  } catch (err: any) {
    next(err);
  }
});

// GET /api/transfers/rates
// Live / Sandbox Exchange Rates
transfersRouter.get('/rates', (req, res) => {
  res.json({
    success: true,
    data: TransferService.getExchangeRates(),
  });
});

// Legacy / Direct Proposal Pass-Throughs (retained for backward compatibility)
transfersRouter.post('/proposals', async (req, res, next) => {
  try {
    const proposal = await bmoniClient.createTransferProposal(req.body);
    res.json({ success: true, data: proposal });
  } catch (err) {
    next(err);
  }
});

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

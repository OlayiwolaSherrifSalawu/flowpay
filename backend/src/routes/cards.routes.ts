import { Router } from 'express';
import { CardService } from '../modules/cards/service.js';

export const cardsRouter = Router();

// GET /api/cards - List cards for smart wallet (preserving reserved cards)
cardsRouter.get('/', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const smartWalletId = req.query.smartWalletId as string | undefined;
    const cards = await CardService.listCards(userId, smartWalletId);
    res.json({ success: true, data: cards });
  } catch (err) {
    next(err);
  }
});

// POST /api/cards - Create virtual card proposal (auto-approved by proxy)
cardsRouter.post('/', async (req, res, next) => {
  try {
    const cardData = await CardService.createVirtualCard(req.body);
    res.json({ success: true, data: cardData });
  } catch (err) {
    next(err);
  }
});

// GET /api/cards/proposals/:proposalId/sign-payload - Poll or fetch sign payload
cardsRouter.get('/proposals/:proposalId/sign-payload', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const payload = await CardService.getProposalSignPayload({
      userId,
      proposalId: req.params.proposalId,
    });
    res.json({ success: true, data: payload });
  } catch (err) {
    next(err);
  }
});

// POST /api/cards/proposals/:proposalId/sign - Submit on-device hardware signature
cardsRouter.post('/proposals/:proposalId/sign', async (req, res, next) => {
  try {
    const userId = (req.body.userId as string) || 'usr_flowpay_sandbox_master';
    const { signature } = req.body;
    const result = await CardService.submitProposalSignature({
      userId,
      proposalId: req.params.proposalId,
      signature,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// GET /api/cards/:cardId/sensitive - Get unmasked sensitive card details
cardsRouter.get('/:cardId/sensitive', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const identityId = req.query.identityId as string | undefined;
    const sensitive = await CardService.getCardSensitiveData(userId, req.params.cardId, identityId);
    res.json({ success: true, data: sensitive });
  } catch (err) {
    next(err);
  }
});

// GET /api/cards/:cardId/transactions - List card transactions (major-unit amounts)
cardsRouter.get('/:cardId/transactions', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const size = req.query.size ? parseInt(req.query.size as string, 10) : 20;
    const status = req.query.status as string | undefined;
    const txs = await CardService.getCardTransactions({
      userId,
      cardId: req.params.cardId,
      size,
      status,
    });
    res.json({ success: true, data: txs });
  } catch (err) {
    next(err);
  }
});

// PUT /api/cards/:cardId/status - Freeze or unfreeze card (BLOCKED or ACTIVE)
cardsRouter.put('/:cardId/status', async (req, res, next) => {
  try {
    const userId = (req.body.userId as string) || 'usr_flowpay_sandbox_master';
    const status = req.body.status as 'BLOCKED' | 'ACTIVE';
    const result = await CardService.updateCardStatus(userId, req.params.cardId, status);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/cards/:cardId/toggle-status - Backward compatible status toggle
cardsRouter.patch('/:cardId/toggle-status', async (req, res, next) => {
  try {
    const userId = (req.body.userId as string) || 'usr_flowpay_sandbox_master';
    const currentStatus = (req.body.currentStatus || 'ACTIVE').toUpperCase();
    const nextStatus: 'BLOCKED' | 'ACTIVE' = currentStatus === 'BLOCKED' || currentStatus === 'FROZEN' ? 'ACTIVE' : 'BLOCKED';
    const result = await CardService.updateCardStatus(userId, req.params.cardId, nextStatus);
    res.json({ success: true, data: { status: result.status.toLowerCase() } });
  } catch (err) {
    next(err);
  }
});

// GET /api/cards/:cardId - Get card detail with ledger and balance
cardsRouter.get('/:cardId', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const smartWalletId = (req.query.smartWalletId as string) || 'sw_default';
    const card = await CardService.getCardDetail(userId, smartWalletId, req.params.cardId);
    res.json({ success: true, data: card });
  } catch (err) {
    next(err);
  }
});

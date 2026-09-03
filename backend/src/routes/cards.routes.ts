import { Router } from 'express';
import { CardService } from '../modules/cards/service.js';

export const cardsRouter = Router();

// GET /api/cards
cardsRouter.get('/', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const cards = await CardService.listCards(userId);
    res.json({ success: true, data: cards });
  } catch (err) {
    next(err);
  }
});

// POST /api/cards
cardsRouter.post('/', async (req, res, next) => {
  try {
    const cardData = await CardService.createVirtualCard(req.body);
    res.json({ success: true, data: cardData });
  } catch (err) {
    next(err);
  }
});

// GET /api/cards/:cardId/transactions
cardsRouter.get('/:cardId/transactions', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const txs = await CardService.getCardTransactions({
      userId,
      cardId: req.params.cardId,
    });
    res.json({ success: true, data: txs });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/cards/:cardId/toggle-status
cardsRouter.patch('/:cardId/toggle-status', async (req, res, next) => {
  try {
    const userId = (req.body.userId as string) || 'usr_flowpay_sandbox_master';
    const currentStatus = req.body.currentStatus || 'active';
    const result = await CardService.toggleCardStatus(userId, req.params.cardId, currentStatus);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

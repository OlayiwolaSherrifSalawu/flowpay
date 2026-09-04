import { Router } from 'express';
import { WalletService } from '../modules/wallets/service.js';

export const walletsRouter = Router();

// GET /api/wallets/balances
walletsRouter.get('/balances', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const balances = await WalletService.getBalances(userId);
    res.json({ success: true, data: balances });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets
walletsRouter.get('/', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const wallets = await WalletService.getWallets(userId);
    res.json({ success: true, data: wallets });
  } catch (err) {
    next(err);
  }
});

// POST /api/wallets/owner-proof-challenge
walletsRouter.post('/owner-proof-challenge', async (req, res, next) => {
  try {
    const { userId, currency, userOwnerAddress } = req.body;
    const challenge = await WalletService.createOwnerProofChallenge({
      userId: userId || 'usr_flowpay_sandbox_master',
      currency: currency || 'USDB',
      userOwnerAddress,
    });
    res.json({ success: true, data: challenge });
  } catch (err) {
    next(err);
  }
});

// POST /api/wallets/create-managed
walletsRouter.post('/create-managed', async (req, res, next) => {
  try {
    const wallet = await WalletService.createManagedWallet(req.body);
    res.json({ success: true, data: wallet });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets/:walletId/balance
walletsRouter.get('/:walletId/balance', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const balance = await WalletService.getWalletBalance(req.params.walletId, userId);
    res.json({ success: true, data: balance });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets/:walletId/transactions
walletsRouter.get('/:walletId/transactions', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const page = parseInt(req.query.page as string) || 1;
    const pageSize = parseInt(req.query.pageSize as string) || 20;
    const txData = await WalletService.getWalletTransactions(req.params.walletId, userId, page, pageSize);
    res.json({ success: true, data: txData });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets/:walletId
walletsRouter.get('/:walletId', async (req, res, next) => {
  try {
    const userId = (req.query.userId as string) || 'usr_flowpay_sandbox_master';
    const wallet = await WalletService.getWalletDetail(req.params.walletId, userId);
    res.json({ success: true, data: wallet });
  } catch (err) {
    next(err);
  }
});

// POST /api/wallets/issue-card (Prepares for Prompt 12 card issuance)
walletsRouter.post('/issue-card', async (req, res, next) => {
  try {
    const { employeeId, walletId, currency, cardType } = req.body;
    res.json({
      success: true,
      data: {
        cardId: `card_${Date.now()}`,
        walletId: walletId || 'sw_default',
        currency: currency || 'USDB',
        type: cardType || 'virtual',
        status: 'active',
        cardLast4: '4289',
        cardHolderName: req.body.cardHolderName || 'Employee',
      },
    });
  } catch (err) {
    next(err);
  }
});

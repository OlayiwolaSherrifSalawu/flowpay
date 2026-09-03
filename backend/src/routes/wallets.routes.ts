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

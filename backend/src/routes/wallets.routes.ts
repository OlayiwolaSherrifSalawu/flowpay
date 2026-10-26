import { authedUserId } from '../auth/session.js';
import { Router, type Request } from 'express';
import { InvalidRequestError } from '../core/errors.js';
import { StellarAccountService } from '../stellar/accounts.js';
import { issueOwnershipChallenge, verifyOwnershipChallenge } from '../stellar/challenge.js';
import { accountForUser, linkAccount } from '../stellar/directory.js';
import { fetchPaymentHistory } from '../stellar/history.js';

/**
 * Wallets = the user's Stellar account. Balances are read from the network; nothing
 * here keeps its own ledger.
 */
export const walletsRouter = Router();
const accounts = new StellarAccountService();

// Identity comes only from the verified session token (see auth/session.ts).
const requestUserId = (req: Request) => authedUserId(req);

async function walletsFor(userId: string) {
  const accountId = await accountForUser(userId);
  if (!accountId) return { accountId: null, wallets: [] as any[] };
  const summary = await accounts.getSummary(accountId);
  return {
    accountId,
    wallets: summary.balances.map((b) => ({
      id: `${accountId}:${b.currency}`,
      address: accountId,
      currency: b.currency,
      balance: b.balance.toMajorString(),
      balanceMinor: b.balance.amountMinor.toString(),
      status: 'active',
    })),
  };
}

// GET /api/wallets — one entry per enabled currency on the user's linked Stellar account.
walletsRouter.get('/', async (req, res, next) => {
  try {
    res.json({ success: true, data: (await walletsFor(requestUserId(req))).wallets });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets/balances
walletsRouter.get('/balances', async (req, res, next) => {
  try {
    const { wallets } = await walletsFor(requestUserId(req));
    res.json({ success: true, data: wallets.map((w) => ({ currency: w.currency, balance: w.balance, balanceMinor: w.balanceMinor })) });
  } catch (err) {
    next(err);
  }
});

// POST /api/wallets/challenge { userId, accountId } → message for the device to sign.
walletsRouter.post('/challenge', (req, res, next) => {
  try {
    const accountId = String(req.body?.accountId ?? '');
    res.json({ success: true, data: issueOwnershipChallenge(accountId, requestUserId(req)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/wallets/register { userId, accountId, message, signature } — links a PROVEN account.
walletsRouter.post('/register', async (req, res, next) => {
  try {
    const userId = requestUserId(req);
    const accountId = String(req.body?.accountId ?? req.body?.address ?? '');
    const { message, signature } = req.body ?? {};
    if (typeof message !== 'string' || typeof signature !== 'string') {
      throw new InvalidRequestError('message and signature from /api/wallets/challenge are required.');
    }
    verifyOwnershipChallenge({ message, signatureHex: signature, accountId, userId });
    await linkAccount(userId, accountId);
    res.json({ success: true, data: { userId, accountId, linked: true } });
  } catch (err) {
    next(err);
  }
});

// GET /api/wallets/transactions?limit=&cursor= — payment history from Horizon.
walletsRouter.get('/transactions', async (req, res, next) => {
  try {
    const accountId = await accountForUser(requestUserId(req));
    if (!accountId) return res.json({ success: true, data: { items: [], nextCursor: null } });
    const history = await fetchPaymentHistory(accountId, {
      limit: req.query.limit ? Number(req.query.limit) : undefined,
      cursor: req.query.cursor as string | undefined,
    });
    res.json({ success: true, data: history });
  } catch (err) {
    next(err);
  }
});

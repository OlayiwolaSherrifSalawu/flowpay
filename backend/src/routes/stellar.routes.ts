import { Router } from 'express';
import { InvalidRequestError, StellarSubmitTimeoutError } from '../core/errors.js';
import { StellarAccountService, type AccountSummary } from '../stellar/accounts.js';
import { assetFor, explorerTxUrl, getNetworkConfig, isStellarCurrency, STELLAR_CURRENCIES, type StellarCurrency } from '../stellar/config.js';
import { StellarHorizon } from '../stellar/horizon.js';

/**
 * Stellar network endpoints. These only read public chain state, build UNSIGNED
 * transactions, and relay transactions the user's device already signed — the backend
 * never holds user keys, so it cannot move user funds on its own.
 */
export const stellarRouter = Router();

const horizon = new StellarHorizon();
const accounts = new StellarAccountService(horizon);

function serializeSummary(s: AccountSummary) {
  return {
    ...s,
    balances: s.balances.map((b) => ({
      currency: b.currency,
      assetCode: b.assetCode,
      assetIssuer: b.assetIssuer,
      amountMinor: b.balance.amountMinor.toString(),
      amount: b.balance.toMajorString(),
      rawBalance: b.rawBalance,
    })),
  };
}

// GET /api/stellar/config — what the client needs to build, sign and display.
stellarRouter.get('/config', (_req, res, next) => {
  try {
    const cfg = getNetworkConfig();
    res.json({
      success: true,
      data: {
        network: cfg.network,
        networkPassphrase: cfg.passphrase,
        horizonUrl: cfg.horizonUrl,
        explorerBaseUrl: cfg.explorerBaseUrl,
        assets: STELLAR_CURRENCIES.map((c) => ({ currency: c, code: assetFor(c).getCode(), issuer: assetFor(c).getIssuer() })),
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/stellar/accounts/:accountId
stellarRouter.get('/accounts/:accountId', async (req, res, next) => {
  try {
    res.json({ success: true, data: serializeSummary(await accounts.getSummary(req.params.accountId)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/stellar/accounts/:accountId/fund — testnet Friendbot (test XLM only).
stellarRouter.post('/accounts/:accountId/fund', async (req, res, next) => {
  try {
    res.json({ success: true, data: await accounts.fundWithFriendbot(req.params.accountId) });
  } catch (err) {
    next(err);
  }
});

// POST /api/stellar/accounts/:accountId/trustlines { currencies?: string[] } → unsigned XDR or null
stellarRouter.post('/accounts/:accountId/trustlines', async (req, res, next) => {
  try {
    const requested: unknown = req.body?.currencies;
    let currencies: StellarCurrency[] | undefined;
    if (requested !== undefined) {
      if (!Array.isArray(requested) || !requested.every((c) => typeof c === 'string' && isStellarCurrency(c))) {
        throw new InvalidRequestError(`currencies must be a subset of ${STELLAR_CURRENCIES.join(', ')}`);
      }
      currencies = requested.map((c: string) => c.toUpperCase() as StellarCurrency);
    }
    res.json({ success: true, data: await accounts.buildTrustlineTx(req.params.accountId, currencies) });
  } catch (err) {
    next(err);
  }
});

// POST /api/stellar/transactions { signedXdr } — relays a device-signed transaction.
stellarRouter.post('/transactions', async (req, res, next) => {
  try {
    const signedXdr = req.body?.signedXdr;
    if (typeof signedXdr !== 'string' || signedXdr.length === 0) throw new InvalidRequestError('signedXdr is required');
    const result = await horizon.submitSignedXdr(signedXdr);
    res.json({ success: true, data: { status: 'COMPLETED', ...result, explorerUrl: explorerTxUrl(result.hash) } });
  } catch (err) {
    if (err instanceof StellarSubmitTimeoutError) {
      // Unknown outcome: 202 + PENDING. The client polls GET /transactions/:hash.
      return res.status(202).json({
        success: false,
        data: { status: 'PENDING', hash: err.hash, explorerUrl: explorerTxUrl(err.hash) },
        code: err.code,
        message: err.message,
      });
    }
    next(err);
  }
});

// GET /api/stellar/transactions/:hash — reconcile a PENDING submission.
stellarRouter.get('/transactions/:hash', async (req, res, next) => {
  try {
    if (!/^[0-9a-f]{64}$/i.test(req.params.hash)) throw new InvalidRequestError('hash must be 64 hex characters');
    const result = await horizon.reconcile(req.params.hash);
    res.json({ success: true, data: { hash: req.params.hash, ...result, explorerUrl: explorerTxUrl(req.params.hash) } });
  } catch (err) {
    next(err);
  }
});

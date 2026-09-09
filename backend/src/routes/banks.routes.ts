import { Router, type Request, type Response, type NextFunction } from 'express';
import { PaystackBankService } from '../modules/banks/paystack.client.js';

export const banksRouter = Router();

/**
 * GET /api/banks
 * Returns list of banks (defaulting to Nigeria).
 * Query parameters:
 *  - country: string (default: 'nigeria')
 *  - search: string (optional search query matching name or bank code)
 */
banksRouter.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const country = (req.query.country as string) || 'nigeria';
    const search = req.query.search as string | undefined;

    const banks = await PaystackBankService.listBanks({ country, search });

    return res.json({
      success: true,
      count: banks.length,
      data: banks,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/banks/resolve
 * Resolves a 10-digit NUBAN bank account number.
 * Query parameters:
 *  - accountNumber: 10-digit account number
 *  - bankCode: bank code (e.g. '058' for GTB, '999992' for OPay)
 */
banksRouter.get('/resolve', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const accountNumber = (req.query.accountNumber || req.query.account_number) as string;
    const bankCode = (req.query.bankCode || req.query.bank_code) as string;

    if (!accountNumber || !bankCode) {
      return res.status(400).json({
        success: false,
        code: 'MISSING_PARAMETERS',
        message: 'Both accountNumber and bankCode query parameters are required.',
      });
    }

    const resolved = await PaystackBankService.resolveAccount(accountNumber, bankCode);

    return res.json({
      success: true,
      data: resolved,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/banks/resolve
 * Resolves a 10-digit NUBAN bank account number via JSON body.
 * Body:
 *  - accountNumber: string
 *  - bankCode: string
 */
banksRouter.post('/resolve', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { accountNumber, account_number, bankCode, bank_code } = req.body || {};
    const accNum = accountNumber || account_number;
    const bCode = bankCode || bank_code;

    if (!accNum || !bCode) {
      return res.status(400).json({
        success: false,
        code: 'MISSING_PARAMETERS',
        message: 'Both accountNumber and bankCode are required in request body.',
      });
    }

    const resolved = await PaystackBankService.resolveAccount(accNum, bCode);

    return res.json({
      success: true,
      data: resolved,
    });
  } catch (err) {
    next(err);
  }
});

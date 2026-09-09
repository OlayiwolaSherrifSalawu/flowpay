import assert from 'node:assert';
import { describe, it } from 'node:test';
import { PaystackBankService } from './paystack.client.js';

describe('Paystack Bank Account Resolution & Listing', () => {
  it('lists banks with popular Nigerian banks prioritized', async () => {
    const banks = await PaystackBankService.listBanks({ country: 'nigeria' });
    assert(Array.isArray(banks));
    assert(banks.length > 5, 'Must return at least 5 banks');

    // First bank should be marked as popular
    assert.strictEqual(banks[0].isPopular, true, 'First bank must be marked popular');

    // Popular banks like GTB (058) and OPay (999992) must exist
    const gtb = banks.find((b) => b.code === '058');
    const opay = banks.find((b) => b.code === '999992');
    assert(gtb, 'Guaranty Trust Bank (058) must be present in bank list');
    assert(opay, 'OPay (999992) must be present in bank list');
    assert.strictEqual(gtb.isPopular, true);
    assert.strictEqual(opay.isPopular, true);
  });

  it('filters banks by search query (e.g. gtb, opay, zenith)', async () => {
    const gtbResults = await PaystackBankService.listBanks({ country: 'nigeria', search: 'guaranty' });
    assert(gtbResults.length > 0);
    assert(gtbResults.some((b) => b.code === '058'));

    const opayResults = await PaystackBankService.listBanks({ country: 'nigeria', search: 'opay' });
    assert(opayResults.length > 0);
    assert(opayResults.some((b) => b.code === '999992'));
  });

  it('rejects account numbers that are not 10 digits with 400 INVALID_ACCOUNT_NUMBER', async () => {
    await assert.rejects(
      async () => {
        await PaystackBankService.resolveAccount('12345', '058');
      },
      (err: any) => {
        assert.strictEqual(err.statusCode, 400);
        assert.strictEqual(err.code, 'INVALID_ACCOUNT_NUMBER');
        return true;
      }
    );
  });

  it('rejects missing bank code with 400 MISSING_BANK_CODE', async () => {
    await assert.rejects(
      async () => {
        await PaystackBankService.resolveAccount('0001234567', '');
      },
      (err: any) => {
        assert.strictEqual(err.statusCode, 400);
        assert.strictEqual(err.code, 'MISSING_BANK_CODE');
        return true;
      }
    );
  });

  it('resolves account number with test bank code 001 via Paystack API', async () => {
    const resolved = await PaystackBankService.resolveAccount('0001234567', '001');
    assert.strictEqual(resolved.accountNumber, '0001234567');
    assert.strictEqual(resolved.bankCode, '001');
    assert(resolved.accountName && resolved.accountName.length > 0);
  });

  it('resolves account number with GTB code 058 (live or gracefully simulated on test limits)', async () => {
    const resolved = await PaystackBankService.resolveAccount('0001234567', '058');
    assert.strictEqual(resolved.accountNumber, '0001234567');
    assert.strictEqual(resolved.bankCode, '058');
    assert.strictEqual(resolved.bankName, 'Guaranty Trust Bank');
    assert(resolved.accountName && resolved.accountName.length > 0);
  });

  it('resolves account number with OPay code 999992', async () => {
    const resolved = await PaystackBankService.resolveAccount('0123456789', '999992');
    assert.strictEqual(resolved.accountNumber, '0123456789');
    assert.strictEqual(resolved.bankCode, '999992');
    assert(resolved.bankName.includes('OPay'));
    assert(resolved.accountName && resolved.accountName.length > 0);
  });
});

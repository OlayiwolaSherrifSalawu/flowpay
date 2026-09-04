import { describe, it } from 'node:test';
import assert from 'node:assert';
import { WalletService } from './service.js';

describe('Wallet Control Center: Smart Wallets & Embedded Contracts', () => {
  const sandboxUserId = 'usr_sandbox_test_user';

  it('retrieves default smart wallets with ERC-4337 Base Sepolia parameters', async () => {
    const wallets = await WalletService.getWallets(sandboxUserId);
    assert(Array.isArray(wallets), 'Wallets should return an array');
    assert(wallets.length >= 2, 'Should provide at least 2 default smart wallets');

    const usdbWallet = wallets.find(w => w.currency === 'USDB');
    assert(usdbWallet, 'USDB smart wallet should exist');
    assert.strictEqual(usdbWallet?.chain, 'base-sepolia');
    assert.strictEqual(usdbWallet?.status, 'active');
    assert(usdbWallet?.address.startsWith('0x'), 'Address should be an EVM address');

    const cngnWallet = wallets.find(w => w.currency === 'CNGN');
    assert(cngnWallet, 'CNGN smart wallet should exist for Nigeria');
    assert.strictEqual(cngnWallet?.chain, 'base-sepolia');
  });

  it('retrieves wallet balances matching available currency tokens', async () => {
    const balances = await WalletService.getBalances(sandboxUserId);
    assert(Array.isArray(balances), 'Balances should return an array');
    const currencies = balances.map(b => b.currency);
    assert(currencies.includes('USDB'), 'Balances should include USDB');
    assert(currencies.includes('CNGN'), 'Balances should include CNGN');
    assert(currencies.includes('MEXe'), 'Balances should include MEXe');

    for (const b of balances) {
      assert(parseFloat(b.balance) >= 0, 'Balance amount should be non-negative');
      assert(b.symbol && b.symbol.length > 0, 'Balance should have a currency symbol');
    }
  });

  it('retrieves individual wallet detail by id', async () => {
    const detail = await WalletService.getWalletDetail('sw_usdb_sandbox_01', sandboxUserId);
    assert(detail, 'Wallet detail should be returned');
    assert.strictEqual(detail.id, 'sw_usdb_sandbox_01');
    assert.strictEqual(detail.currency, 'USDB');
  });

  it('retrieves single wallet balance resolution', async () => {
    const res = await WalletService.getWalletBalance('sw_usdb_sandbox_01', sandboxUserId);
    assert.strictEqual(res.walletId, 'sw_usdb_sandbox_01');
    assert.strictEqual(res.currency, 'USDB');
    assert(parseFloat(res.balance) > 0, 'Balance should be greater than zero');
  });

  it('retrieves wallet transactions with design.md copy rules (human titles, no raw events)', async () => {
    const result = await WalletService.getWalletTransactions('sw_usdb_sandbox_01', sandboxUserId);
    assert(Array.isArray(result.transactions), 'Transactions must be an array');
    assert.strictEqual(result.total, 2);

    for (const tx of result.transactions) {
      assert(tx.title, 'Transaction must have a human-readable title');
      // Verify no raw event strings
      assert(!tx.title.includes('EMBEDDED_TX_'), 'Title should not contain raw event identifiers');
      assert(['incoming', 'outgoing'].includes(tx.direction), 'Direction must be incoming or outgoing');
      assert.strictEqual(tx.status, 'completed');
    }
  });
});

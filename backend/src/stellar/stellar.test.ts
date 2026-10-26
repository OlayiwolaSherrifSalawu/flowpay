import test from 'node:test';
import assert from 'node:assert';
import { Account, Keypair, Networks, Operation, TransactionBuilder, Asset } from '@stellar/stellar-sdk';

// Deterministic config for tests (dotenv never overrides values already set).
const ISSUER = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = ISSUER;
delete process.env.STELLAR_ASSET_USD;

const { Money } = await import('../core/money.js');
const { StellarError, StellarSubmitTimeoutError, StellarAccountNotFoundError } = await import('../core/errors.js');
const { toStellarAmount, fromStellarAmountCeil, withSlippage } = await import('./amount.js');
const { assetFor, currencyForAsset, parseAssetString } = await import('./config.js');
const { StellarHorizon, mapHorizonError, describeResultCodes } = await import('./horizon.js');
const { StellarAccountService, summarizeAccount } = await import('./accounts.js');

const httpError = (status: number | undefined, data?: unknown) =>
  Object.assign(new Error(`HTTP ${status}`), { response: status === undefined ? undefined : { status, data } });

function signedXdr(signer = Keypair.random()) {
  const tx = new TransactionBuilder(new Account(signer.publicKey(), '1'), { fee: '100', networkPassphrase: Networks.TESTNET })
    .addOperation(Operation.payment({ destination: Keypair.random().publicKey(), asset: Asset.native(), amount: '1' }))
    .setTimeout(60)
    .build();
  tx.sign(signer);
  return { xdr: tx.toXDR(), hash: Buffer.from(tx.hash()).toString('hex') };
}

function fakeGateway(overrides: Record<string, any> = {}): any {
  return {
    loadAccount: async () => { throw httpError(404); },
    submitTransaction: async () => ({ successful: true, hash: 'h', ledger: 1 }),
    getTransaction: async () => { throw httpError(404); },
    strictReceivePaths: async () => [],
    fetchBaseFee: async () => 100,
    ...overrides,
  };
}

// ── amounts ──────────────────────────────────────────────────────────────────

test('Stellar amount - Money converts to a positive decimal string', () => {
  assert.strictEqual(toStellarAmount(Money.fromMinor(1050, 'USD')), '10.50');
  assert.throws(() => toStellarAmount(Money.zero('USD')), RangeError);
});

test('Stellar amount - quoted costs round UP so we never under-quote', () => {
  assert.strictEqual(fromStellarAmountCeil('446.5102060', 'CAD').amountMinor, 44652n);
  assert.strictEqual(fromStellarAmountCeil('10.5000000', 'USD').amountMinor, 1050n);
});

test('Stellar amount - slippage cap adds bps, minimum one minor unit', () => {
  assert.strictEqual(withSlippage(Money.fromMinor(10000, 'USD'), 100).amountMinor, 10100n);
  assert.strictEqual(withSlippage(Money.fromMinor(5, 'USD'), 100).amountMinor, 6n);
});

// ── config ───────────────────────────────────────────────────────────────────

test('Stellar config - resolves FlowPay assets and maps balances back', () => {
  const ngn = assetFor('NGN');
  assert.strictEqual(ngn.getCode(), 'NGN');
  assert.strictEqual(ngn.getIssuer(), ISSUER);
  assert.strictEqual(currencyForAsset('NGN', ISSUER), 'NGN');
  assert.strictEqual(currencyForAsset('NGN', Keypair.random().publicKey()), null);
  assert.throws(() => parseAssetString('USDC:not-a-key'));
});

// ── error mapping (money-safety) ─────────────────────────────────────────────

test('Horizon errors - tx_failed result codes become a FAILED StellarError with a human message', () => {
  const err = mapHorizonError(httpError(400, { extras: { result_codes: { transaction: 'tx_failed', operations: ['op_underfunded'] } } }), 'abc');
  assert.ok(err instanceof StellarError);
  assert.ok(!(err instanceof StellarSubmitTimeoutError));
  assert.strictEqual(err.code, 'STELLAR_TX_FAILED');
  assert.match(err.message, /Insufficient balance/);
  assert.deepStrictEqual(err.resultCodes?.operations, ['op_underfunded']);
});

test('Horizon errors - submit timeout (504) and dropped connection are PENDING, not failed', () => {
  const t1 = mapHorizonError(httpError(504, { type: 'https://stellar.org/horizon-errors/timeout' }), 'h1');
  const t2 = mapHorizonError(httpError(undefined), 'h2');
  assert.ok(t1 instanceof StellarSubmitTimeoutError && t1.hash === 'h1');
  assert.ok(t2 instanceof StellarSubmitTimeoutError && t2.hash === 'h2');
});

test('Horizon errors - unknown result codes still explain themselves', () => {
  assert.match(describeResultCodes({ transaction: 'tx_failed', operations: ['op_weird'] }), /op_weird/);
});

// ── submit / reconcile ───────────────────────────────────────────────────────

test('StellarHorizon.submitSignedXdr - returns the real hash only on success', async () => {
  const { xdr, hash } = signedXdr();
  const h = new StellarHorizon(fakeGateway({ submitTransaction: async () => ({ successful: true, hash, ledger: 42 }) }));
  assert.deepStrictEqual(await h.submitSignedXdr(xdr), { hash, ledger: 42, successful: true });
});

test('StellarHorizon.submitSignedXdr - rejection propagates, never a fake success', async () => {
  const { xdr } = signedXdr();
  const h = new StellarHorizon(fakeGateway({
    submitTransaction: async () => { throw httpError(400, { extras: { result_codes: { transaction: 'tx_bad_seq' } } }); },
  }));
  await assert.rejects(h.submitSignedXdr(xdr), (e: any) => e.code === 'STELLAR_TX_FAILED' && /out of date/.test(e.message));
});

test('StellarHorizon.submitSignedXdr - timeout surfaces the locally computed hash for reconciliation', async () => {
  const { xdr, hash } = signedXdr();
  const h = new StellarHorizon(fakeGateway({ submitTransaction: async () => { throw httpError(504, {}); } }));
  await assert.rejects(h.submitSignedXdr(xdr), (e: any) => e instanceof StellarSubmitTimeoutError && e.hash === hash);
});

test('StellarHorizon.submitSignedXdr - refuses unsigned and malformed envelopes', async () => {
  const unsigned = new TransactionBuilder(new Account(Keypair.random().publicKey(), '1'), { fee: '100', networkPassphrase: Networks.TESTNET })
    .addOperation(Operation.bumpSequence({ bumpTo: '2' }))
    .setTimeout(60)
    .build()
    .toXDR();
  const h = new StellarHorizon(fakeGateway());
  await assert.rejects(h.submitSignedXdr(unsigned), (e: any) => e.code === 'STELLAR_UNSIGNED_TX');
  await assert.rejects(h.submitSignedXdr('garbage'), (e: any) => e.code === 'STELLAR_INVALID_XDR');
});

test('StellarHorizon.reconcile - unseen hash is PENDING, known hash reports its real outcome', async () => {
  assert.deepStrictEqual(await new StellarHorizon(fakeGateway()).reconcile('x'), { status: 'PENDING' });
  const seen = new StellarHorizon(fakeGateway({ getTransaction: async () => ({ hash: 'x', ledger: 7, successful: false }) }));
  assert.deepStrictEqual(await seen.reconcile('x'), { status: 'FAILED', ledger: 7 });
});

test('StellarHorizon.loadAccount - 404 is a typed not-found error', async () => {
  const id = Keypair.random().publicKey();
  await assert.rejects(new StellarHorizon(fakeGateway()).loadAccount(id), (e: any) => e instanceof StellarAccountNotFoundError);
});

// ── accounts ─────────────────────────────────────────────────────────────────

function fakeAccount(id: string, balances: any[]) {
  return Object.assign(new Account(id, '100'), { balances }) as any;
}

test('summarizeAccount - FlowPay balances, XLM and missing trustlines', () => {
  const id = Keypair.random().publicKey();
  const s = summarizeAccount(id, fakeAccount(id, [
    { asset_type: 'native', balance: '9999.5000000' },
    { asset_type: 'credit_alphanum4', asset_code: 'USD', asset_issuer: ISSUER, balance: '120.3456789' },
    { asset_type: 'credit_alphanum4', asset_code: 'USD', asset_issuer: Keypair.random().publicKey(), balance: '5' },
  ]));
  assert.strictEqual(s.exists, true);
  assert.strictEqual(s.xlmBalance, '9999.5000000');
  assert.strictEqual(s.balances.length, 1, 'foreign-issuer USD is ignored');
  assert.strictEqual(s.balances[0].balance.amountMinor, 12034n, 'balances round toward zero');
  assert.deepStrictEqual(s.missingTrustlines, ['CAD', 'MXN', 'GBP', 'NGN']);
});

test('summarizeAccount - unfunded account needs everything', () => {
  const s = summarizeAccount(Keypair.random().publicKey(), null);
  assert.strictEqual(s.exists, false);
  assert.strictEqual(s.missingTrustlines.length, 5);
});

test('StellarAccountService.buildTrustlineTx - only adds missing trustlines, unsigned', async () => {
  const id = Keypair.random().publicKey();
  const svc = new StellarAccountService(new StellarHorizon(fakeGateway({
    loadAccount: async () => fakeAccount(id, [
      { asset_type: 'native', balance: '100' },
      { asset_type: 'credit_alphanum4', asset_code: 'USD', asset_issuer: ISSUER, balance: '0' },
    ]),
  })));
  const res = await svc.buildTrustlineTx(id);
  assert.ok(res);
  assert.deepStrictEqual(res.currencies, ['CAD', 'MXN', 'GBP', 'NGN']);
  const tx = TransactionBuilder.fromXDR(res.xdr, Networks.TESTNET) as any;
  assert.strictEqual(tx.signatures.length, 0);
  assert.deepStrictEqual(tx.operations.map((o: any) => o.type), Array(4).fill('changeTrust'));
});

test('StellarAccountService.fundWithFriendbot - already-funded is not an error; other failures are', async () => {
  const id = Keypair.random().publicKey();
  const svc = new StellarAccountService(new StellarHorizon(fakeGateway()));
  const already = async () => new Response(JSON.stringify({ extras: { result_codes: { operations: ['op_already_exists'] } } }), { status: 400 });
  assert.deepStrictEqual(await svc.fundWithFriendbot(id, already as any), { funded: false, alreadyExisted: true });
  const broken = async () => new Response(JSON.stringify({ detail: 'boom' }), { status: 500 });
  await assert.rejects(svc.fundWithFriendbot(id, broken as any), (e: any) => e.code === 'STELLAR_FRIENDBOT_FAILED');
  await assert.rejects(svc.fundWithFriendbot('nope', already as any), /valid Stellar account/);
});

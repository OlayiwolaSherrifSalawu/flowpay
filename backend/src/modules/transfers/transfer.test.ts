import test from 'node:test';
import assert from 'node:assert';
import { Account, Keypair, Networks, TransactionBuilder } from '@stellar/stellar-sdk';

const ISSUER = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = ISSUER;

const { StellarHorizon } = await import('../../stellar/horizon.js');
const { TransferService, setTransferHorizonForTests } = await import('./service.js');
const { linkAccount, resolveRecipient, resetDirectoryForTests } = await import('../../stellar/directory.js');
const { registeredUsers } = await import('../../routes/auth.routes.js');
const { listInMemoryActivities } = await import('../../routes/activity.routes.js');
const { issueOwnershipChallenge, verifyOwnershipChallenge } = await import('../../stellar/challenge.js');

const sender = Keypair.random();
const receiver = Keypair.random();
const httpError = (status: number | undefined, data?: unknown) =>
  Object.assign(new Error(`HTTP ${status}`), { response: status === undefined ? undefined : { status, data } });

const line = (code: string, balance: string) => ({ asset_type: 'credit_alphanum4', asset_code: code, asset_issuer: ISSUER, balance });
const ALL_LINES = (overrides: Record<string, string> = {}) =>
  ['USD', 'CAD', 'MXN', 'GBP', 'NGN'].map((c) => line(c, overrides[c] ?? '0'));

interface FakeState {
  balances: Record<string, any[]>;
  submit: (tx: any) => Promise<any>;
  quotes: (src: any[], dest: any, amount: string) => any[];
  submitted: any[];
}

function setup(overrides: Partial<FakeState> = {}): FakeState {
  const state: FakeState = {
    balances: {
      [sender.publicKey()]: [{ asset_type: 'native', balance: '100' }, ...ALL_LINES({ USD: '250', NGN: '1000000' })],
      [receiver.publicKey()]: [{ asset_type: 'native', balance: '100' }, ...ALL_LINES()],
    },
    submitted: [],
    submit: async (tx) => ({ successful: true, hash: Buffer.from(tx.hash()).toString('hex'), ledger: 77 }),
    // 1 USD = 1550 NGN, conversion cost baked in.
    quotes: (src, dest, amount) =>
      src[0].getCode() === 'NGN' && dest.getCode() === 'USD'
        ? [{ sourceAsset: { code: 'NGN', issuer: ISSUER }, sourceAmount: (Number(amount) * 1555).toFixed(7), destinationAmount: amount, path: [] }]
        : [],
    ...overrides,
  };
  setTransferHorizonForTests(
    new StellarHorizon({
      loadAccount: async (id: string) => {
        if (!state.balances[id]) throw httpError(404);
        return Object.assign(new Account(id, '1000'), { balances: state.balances[id] }) as any;
      },
      submitTransaction: async (tx: any) => {
        state.submitted.push(tx);
        return state.submit(tx);
      },
      getTransaction: async () => { throw httpError(404); },
      strictReceivePaths: async (src: any, dest: any, amt: string) => state.quotes(src, dest, amt),
      fetchBaseFee: async () => 100,
    } as any)
  );
  return state;
}

resetDirectoryForTests();
registeredUsers.set('usr_alice', { userId: 'usr_alice', fullName: 'Alice Ade', email: 'alice@flowpay.test', accountType: 'personal', country: 'NG', phone: '+2348000000001', kycStatus: 'verified' });
registeredUsers.set('usr_bob', { userId: 'usr_bob', fullName: 'Bob Diaz', email: 'bob@flowpay.test', accountType: 'personal', country: 'US', phone: '+14155550002', kycStatus: 'verified' });
registeredUsers.set('usr_bob2', { userId: 'usr_bob2', fullName: 'Bob Diaz', email: 'bob2@flowpay.test', accountType: 'personal', country: 'US', phone: '+14155550003', kycStatus: 'verified' });
registeredUsers.set('usr_nowallet', { userId: 'usr_nowallet', fullName: 'No Wallet', email: 'none@flowpay.test', accountType: 'personal', country: 'US', phone: '+14155550009', kycStatus: 'verified' });
await linkAccount('usr_alice', sender.publicKey());
await linkAccount('usr_bob', receiver.publicKey());

const intent = (amount: string, currency = 'USD', recipient = 'bob@flowpay.test') => ({
  intentId: 'i1',
  originalPrompt: 'test',
  recipient,
  amount,
  amountMinor: String(Math.round(Number(amount) * 100)),
  currency,
  purpose: 'Rent for October flat 3B and utilities',
  confidenceScore: 1,
  requiresExplicitApproval: true,
});

function signed(xdr: string, kp = sender) {
  const tx = TransactionBuilder.fromXDR(xdr, Networks.TESTNET);
  tx.sign(kp);
  return tx.toXDR();
}

// ── recipient resolution (strict) ────────────────────────────────────────────

test('resolveRecipient - exact email / phone / account ID; never fuzzy', async () => {
  setup();
  assert.strictEqual((await resolveRecipient('BOB@flowpay.test')).accountId, receiver.publicKey());
  assert.strictEqual((await resolveRecipient('+1 415 555 0002')).accountId, receiver.publicKey());
  assert.strictEqual((await resolveRecipient(receiver.publicKey())).userId, 'usr_bob');
  await assert.rejects(resolveRecipient('Bob'), /No FlowPay user matches/, 'partial names must not match');
  await assert.rejects(resolveRecipient('Bob Diaz'), /more than one FlowPay user/);
  await assert.rejects(resolveRecipient('none@flowpay.test'), /has not set up their FlowPay wallet/);
});

// ── funding quotes ───────────────────────────────────────────────────────────

test('inspectBalances - direct USD funding when balance covers it', async () => {
  setup();
  const r = await TransferService.inspectBalances({ userId: 'usr_alice', intent: intent('100.00') });
  assert.strictEqual(r.isPossible, true);
  assert.strictEqual(r.isDirectFunded, true);
  assert.strictEqual(r.recommendedFundingOption?.fundingCurrency, 'USD');
  assert.strictEqual(r.recommendedFundingOption?.totalDebitMinor, '10000');
});

test('inspectBalances - falls back to a live NGN→USD path quote when USD is short', async () => {
  setup();
  const r = await TransferService.inspectBalances({ userId: 'usr_alice', intent: intent('300.00') });
  assert.strictEqual(r.isPossible, true);
  assert.strictEqual(r.isDirectFunded, false);
  const ngn = r.recommendedFundingOption!;
  assert.strictEqual(ngn.fundingCurrency, 'NGN');
  assert.strictEqual(ngn.requiresConversion, true);
  assert.strictEqual(ngn.convertedDebitMinor, String(300 * 1555 * 100));
  assert.strictEqual(ngn.totalDebitMinor, String(300 * 1555 * 101), 'sendMax includes 1% slippage cap');
});

test('inspectBalances - impossible transfers say so (no invented balance)', async () => {
  setup();
  const r = await TransferService.inspectBalances({ userId: 'usr_alice', intent: intent('5000.00') });
  assert.strictEqual(r.isPossible, false);
  assert.match(r.reason!, /Not enough balance/);
});

test('inspectBalances - unsupported currency is a 400, not a 500', async () => {
  setup();
  await assert.rejects(TransferService.inspectBalances({ userId: 'usr_alice', intent: intent('10.00', 'EUR') }), (e: any) => e.statusCode === 400);
});

// ── proposals ────────────────────────────────────────────────────────────────

test('createProposal - same-currency payment XDR to the resolved account, unsigned, memo ≤ 28 bytes', async () => {
  setup();
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('100.00'), fundingOption: { fundingCurrency: 'USD' } });
  const tx = TransactionBuilder.fromXDR(p.signPayload, Networks.TESTNET) as any;
  assert.strictEqual(tx.signatures.length, 0);
  assert.strictEqual(tx.source, sender.publicKey());
  assert.strictEqual(tx.operations[0].type, 'payment');
  assert.strictEqual(tx.operations[0].destination, receiver.publicKey());
  assert.strictEqual(tx.operations[0].amount, '100.0000000');
  assert.ok(tx.memo.value.length > 0 && tx.memo.value.length <= 28, 'memo is 1..28 bytes');
  assert.strictEqual(p.proposalId, Buffer.from(tx.hash()).toString('hex'));
  assert.strictEqual(p.recipientName, 'Bob Diaz');
});

test('createProposal - conversion builds pathPaymentStrictReceive with a sendMax cap', async () => {
  setup();
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('300.00'), fundingOption: { fundingCurrency: 'NGN' } });
  const op = (TransactionBuilder.fromXDR(p.signPayload, Networks.TESTNET) as any).operations[0];
  assert.strictEqual(op.type, 'pathPaymentStrictReceive');
  assert.strictEqual(op.sendAsset.getCode(), 'NGN');
  assert.strictEqual(op.destAsset.getCode(), 'USD');
  assert.strictEqual(op.destAmount, '300.0000000');
  assert.strictEqual(op.sendMax, (300 * 1555 * 1.01).toFixed(7));
});

test('createProposal - refuses when the chosen wallet cannot cover it', async () => {
  setup();
  await assert.rejects(
    TransferService.createProposal({ userId: 'usr_alice', intent: intent('300.00'), fundingOption: { fundingCurrency: 'USD' } }),
    (e: any) => e.code === 'INSUFFICIENT_FUNDS'
  );
});

test('createProposal - recipient without the currency enabled gets a clear error', async () => {
  const state = setup();
  state.balances[receiver.publicKey()] = [{ asset_type: 'native', balance: '100' }];
  await assert.rejects(
    TransferService.createProposal({ userId: 'usr_alice', intent: intent('10.00'), fundingOption: { fundingCurrency: 'USD' } }),
    /has not enabled USD/
  );
});

// ── execution (money-safety) ────────────────────────────────────────────────

test('executeTransfer - success returns the REAL Horizon hash and logs both sides', async () => {
  const state = setup();
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('25.00'), fundingOption: { fundingCurrency: 'USD' } });
  const r = await TransferService.executeTransfer({ userId: 'usr_alice', proposalId: p.proposalId, signedXdr: signed(p.signPayload) });
  assert.strictEqual(r.status, 'COMPLETED');
  assert.strictEqual(r.transactionHash, p.proposalId);
  assert.strictEqual(state.submitted.length, 1);
  const recent = listInMemoryActivities().slice(0, 2).map((a: any) => `${a.action}:${a.actor}`);
  assert.deepStrictEqual(recent.sort(), ['TRANSFER_COMPLETED:usr_alice', 'TRANSFER_RECEIVED:usr_bob']);
  await assert.rejects(
    TransferService.executeTransfer({ userId: 'usr_alice', proposalId: p.proposalId, signedXdr: signed(p.signPayload) }),
    /not found or has expired/,
    'a proposal cannot be executed twice'
  );
});

test('executeTransfer - a different transaction cannot be swapped in', async () => {
  setup();
  const p1 = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('25.00'), fundingOption: { fundingCurrency: 'USD' } });
  const p2 = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('99.00'), fundingOption: { fundingCurrency: 'USD' } });
  await assert.rejects(
    TransferService.executeTransfer({ userId: 'usr_alice', proposalId: p1.proposalId, signedXdr: signed(p2.signPayload) }),
    /does not match/
  );
});

test('executeTransfer - Horizon rejection propagates as FAILED, recorded, never COMPLETED', async () => {
  setup({
    submit: async () => { throw httpError(400, { extras: { result_codes: { transaction: 'tx_failed', operations: ['op_underfunded'] } } }); },
  });
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('25.00'), fundingOption: { fundingCurrency: 'USD' } });
  await assert.rejects(
    TransferService.executeTransfer({ userId: 'usr_alice', proposalId: p.proposalId, signedXdr: signed(p.signPayload) }),
    (e: any) => e.code === 'STELLAR_TX_FAILED'
  );
  const last = listInMemoryActivities()[0];
  assert.strictEqual(last.action, 'TRANSFER_FAILED');
  assert.strictEqual(last.detailsJson.status, 'FAILED');
});

test('executeTransfer - timeout is PENDING with the hash, not success and not failure', async () => {
  setup({ submit: async () => { throw httpError(504, {}); } });
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('25.00'), fundingOption: { fundingCurrency: 'USD' } });
  await assert.rejects(
    TransferService.executeTransfer({ userId: 'usr_alice', proposalId: p.proposalId, signedXdr: signed(p.signPayload) }),
    (e: any) => e.code === 'STELLAR_SUBMIT_PENDING' && e.hash === p.proposalId
  );
  assert.strictEqual(listInMemoryActivities()[0].action, 'TRANSFER_PENDING');
});

test('executeTransfer - another user cannot execute my proposal', async () => {
  setup();
  const p = await TransferService.createProposal({ userId: 'usr_alice', intent: intent('25.00'), fundingOption: { fundingCurrency: 'USD' } });
  await assert.rejects(
    TransferService.executeTransfer({ userId: 'usr_bob', proposalId: p.proposalId, signedXdr: signed(p.signPayload) }),
    /not found/
  );
});

// ── ownership challenge ─────────────────────────────────────────────────────

test('ownership challenge - valid signature links; tampering, wrong key, reuse and expiry are rejected', () => {
  const kp = Keypair.random();
  const c = issueOwnershipChallenge(kp.publicKey(), 'usr_x');
  const sig = Buffer.from(kp.sign(Buffer.from(c.message, 'utf8'))).toString('hex');
  assert.deepStrictEqual(verifyOwnershipChallenge({ message: c.message, signatureHex: sig, accountId: kp.publicKey(), userId: 'usr_x' }), {
    accountId: kp.publicKey(),
    userId: 'usr_x',
  });
  assert.throws(() => verifyOwnershipChallenge({ message: c.message, signatureHex: sig, accountId: kp.publicKey(), userId: 'usr_x' }), /already used/);

  const c2 = issueOwnershipChallenge(kp.publicKey(), 'usr_x');
  const wrongSig = Buffer.from(Keypair.random().sign(Buffer.from(c2.message, 'utf8'))).toString('hex');
  assert.throws(() => verifyOwnershipChallenge({ message: c2.message, signatureHex: wrongSig, accountId: kp.publicKey(), userId: 'usr_x' }), /does not match this Stellar account/);
  assert.throws(() => verifyOwnershipChallenge({ message: c2.message.replace('usr_x', 'usr_y'), signatureHex: wrongSig, accountId: kp.publicKey(), userId: 'usr_y' }), /not issued by FlowPay/);

  const old = issueOwnershipChallenge(kp.publicKey(), 'usr_x', Date.now() - 10 * 60 * 1000);
  const oldSig = Buffer.from(kp.sign(Buffer.from(old.message, 'utf8'))).toString('hex');
  assert.throws(() => verifyOwnershipChallenge({ message: old.message, signatureHex: oldSig, accountId: kp.publicKey(), userId: 'usr_x' }), /expired/);
});

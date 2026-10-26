import test from 'node:test';
import assert from 'node:assert';
import { Account, Keypair, Networks, TransactionBuilder } from '@stellar/stellar-sdk';

const ISSUER = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = ISSUER;

const { StellarHorizon } = await import('../../stellar/horizon.js');
const { BatchPaymentService, setBatchHorizonForTests } = await import('./batch_service.js');
const { MoneyMissionService, legsForMission } = await import('../missions/service.js');
const { linkAccount, resetDirectoryForTests } = await import('../../stellar/directory.js');
const { registeredUsers } = await import('../../routes/auth.routes.js');

const me = Keypair.random();
const friend = Keypair.random();
const line = (code: string, balance: string) => ({ asset_type: 'credit_alphanum4', asset_code: code, asset_issuer: ISSUER, balance });
const lines = (o: Record<string, string>) => ['USD', 'CAD', 'MXN', 'GBP', 'NGN'].map((c) => line(c, o[c] ?? '0'));
const httpError = (status: number, data?: unknown) => Object.assign(new Error(`HTTP ${status}`), { response: { status, data } });

function setup(opts: { submit?: (tx: any) => Promise<any> } = {}) {
  const balances: Record<string, any[]> = {
    [me.publicKey()]: [{ asset_type: 'native', balance: '100' }, ...lines({ USD: '2000' })],
    [friend.publicKey()]: [{ asset_type: 'native', balance: '100' }, ...lines({})],
  };
  const submitted: any[] = [];
  setBatchHorizonForTests(
    new StellarHorizon({
      loadAccount: async (id: string) => {
        if (!balances[id]) throw httpError(404);
        return Object.assign(new Account(id, '500'), { balances: balances[id] }) as any;
      },
      submitTransaction: async (tx: any) => {
        submitted.push(tx);
        return opts.submit ? opts.submit(tx) : { successful: true, hash: Buffer.from(tx.hash()).toString('hex'), ledger: 9 };
      },
      getTransaction: async () => { throw httpError(404); },
      // 1 USD → 1550 NGN, 1 USD → 1.375 CAD (before fees)
      strictReceivePaths: async (src: any[], dest: any, amt: string) => {
        const rate = dest.getCode() === 'NGN' ? 1550 : 1.375;
        return [{ sourceAsset: { code: src[0].getCode(), issuer: ISSUER }, sourceAmount: (Number(amt) / rate * 1.003).toFixed(7), destinationAmount: amt, path: [] }];
      },
      strictSendPaths: async (src: any, amt: string, dests: any[]) => {
        const rate = dests[0].getCode() === 'NGN' ? 1550 : 1.375;
        return [{ sourceAsset: { code: src.getCode(), issuer: ISSUER }, sourceAmount: amt, destinationAmount: (Number(amt) * rate * 0.997).toFixed(7), path: [] }];
      },
      fetchBaseFee: async () => 100,
    } as any)
  );
  return { submitted };
}

resetDirectoryForTests();
registeredUsers.set('usr_me', { userId: 'usr_me', fullName: 'Me Myself', email: 'me@flowpay.test', accountType: 'personal', country: 'US', phone: '+15550000001', kycStatus: 'verified' });
registeredUsers.set('usr_friend', { userId: 'usr_friend', fullName: 'Friend One', email: 'friend@flowpay.test', accountType: 'personal', country: 'MX', phone: '+15550000002', kycStatus: 'verified' });
await linkAccount('usr_me', me.publicKey());
await linkAccount('usr_friend', friend.publicKey());

const sign = (xdr: string) => {
  const tx = TransactionBuilder.fromXDR(xdr, Networks.TESTNET);
  tx.sign(me);
  return tx.toXDR();
};
const ops = (xdr: string) => (TransactionBuilder.fromXDR(xdr, Networks.TESTNET) as any).operations;

// ── batch builder ────────────────────────────────────────────────────────────

test('batch - pay two people + convert + lock savings in ONE transaction', async () => {
  setup();
  const unlock = new Date(Date.now() + 7 * 86_400_000).toISOString();
  const p = await BatchPaymentService.propose({
    userId: 'usr_me',
    context: { purpose: 'AI_PLAN' },
    legs: [
      { label: 'Mom', to: 'friend@flowpay.test', mode: 'exact_receive', amount: { amountMinor: '2000', currency: 'USD' } },
      { label: 'Dad (NGN)', to: friend.publicKey(), mode: 'exact_receive', amount: { amountMinor: '1550000', currency: 'NGN' }, fundingCurrency: 'USD' },
      { label: 'To CAD', to: 'self', mode: 'exact_send', amount: { amountMinor: '10000', currency: 'USD' }, destCurrency: 'CAD' },
      { label: 'Tax vault', to: 'self', mode: 'exact_send', amount: { amountMinor: '5000', currency: 'USD' }, lockUntil: unlock },
    ],
  });
  const o = ops(p.signPayload);
  assert.deepStrictEqual(o.map((x: any) => x.type), ['payment', 'pathPaymentStrictReceive', 'pathPaymentStrictSend', 'createClaimableBalance']);
  assert.strictEqual(o[2].destination, me.publicKey(), 'conversion pays yourself');
  assert.strictEqual(o[3].claimants[0].destination, me.publicKey(), 'only you can claim your savings');
  assert.strictEqual(o[3].amount, '50.0000000');
  assert.strictEqual(p.legs.length, 4);
  assert.ok(Number(p.maxTotals.USD) > 20 + 10 + 100 + 50, 'worst-case USD spend covers every leg');
});

test('batch - refuses when the combined worst case exceeds the balance', async () => {
  setup();
  await assert.rejects(
    BatchPaymentService.propose({
      userId: 'usr_me',
      context: { purpose: 'AI_PLAN' },
      legs: [
        { label: 'A', to: 'friend@flowpay.test', mode: 'exact_receive', amount: { amountMinor: '150000', currency: 'USD' } },
        { label: 'B', to: 'friend@flowpay.test', mode: 'exact_receive', amount: { amountMinor: '60000', currency: 'USD' } },
      ],
    }),
    (e: any) => e.code === 'INSUFFICIENT_FUNDS'
  );
});

test('batch - guards: no self-payments, no locking other people\'s money, no past lock dates', async () => {
  setup();
  const propose = (leg: any) => BatchPaymentService.propose({ userId: 'usr_me', context: { purpose: 'X' }, legs: [leg] });
  await assert.rejects(propose({ label: 'x', to: me.publicKey(), mode: 'exact_receive', amount: { amountMinor: '100', currency: 'USD' } }), /use "self"/);
  await assert.rejects(propose({ label: 'x', to: 'friend@flowpay.test', mode: 'exact_send', amount: { amountMinor: '100', currency: 'USD' }, lockUntil: new Date(Date.now() + 1e7).toISOString() }), /only your own savings/);
  await assert.rejects(propose({ label: 'x', to: 'self', mode: 'exact_send', amount: { amountMinor: '100', currency: 'USD' }, lockUntil: '2020-01-01T00:00:00Z' }), /must be in the future/);
  await assert.rejects(propose({ label: 'x', to: 'self', mode: 'exact_send', amount: { amountMinor: '100', currency: 'USD' } }), /does nothing/);
});

test('batch execute - atomic success logs every leg with the same real hash', async () => {
  const { submitted } = setup();
  const p = await BatchPaymentService.propose({
    userId: 'usr_me',
    context: { purpose: 'AI_PLAN' },
    legs: [{ label: 'Mom', to: 'friend@flowpay.test', mode: 'exact_receive', amount: { amountMinor: '2000', currency: 'USD' } }],
  });
  const r = await BatchPaymentService.execute({ userId: 'usr_me', proposalId: p.proposalId, signedXdr: sign(p.signPayload) });
  assert.strictEqual(r.status, 'COMPLETED');
  assert.strictEqual(r.transactionHash, p.proposalId);
  assert.strictEqual(submitted.length, 1);
});

test('batch execute - rejection means nothing settled; error propagates', async () => {
  setup({ submit: async () => { throw httpError(400, { extras: { result_codes: { transaction: 'tx_failed', operations: ['op_success', 'op_over_source_max'] } } }); } });
  const p = await BatchPaymentService.propose({
    userId: 'usr_me',
    context: { purpose: 'AI_PLAN' },
    legs: [{ label: 'Mom', to: 'friend@flowpay.test', mode: 'exact_receive', amount: { amountMinor: '2000', currency: 'USD' } }],
  });
  await assert.rejects(BatchPaymentService.execute({ userId: 'usr_me', proposalId: p.proposalId, signedXdr: sign(p.signPayload) }), /exchange rate moved/);
});

// ── missions ────────────────────────────────────────────────────────────────

const flagship = {
  intentId: 'i1',
  originalPrompt: 'split',
  intentType: 'SPLIT_INCOMING',
  ruleTitle: '3-way split',
  triggerCondition: { type: 'MANUAL', sourceCurrency: 'USD', sourceAmount: '2000.00', sourceAmountMinor: '200000', description: 'manual' },
  allocations: [
    { id: 'a1', category: 'RESERVE', label: 'USD reserve', percentage: 30, targetCurrency: 'USD', sourceAmountMinor: '60000', sourceAmountFormatted: '$600.00', destinationWalletTag: 'USD', actionType: 'HOLD' },
    { id: 'a2', category: 'EXPENSES', label: 'Naira expenses', percentage: 50, targetCurrency: 'NGN', sourceAmountMinor: '100000', sourceAmountFormatted: '$1,000.00', destinationWalletTag: 'NGN', actionType: 'CONVERT_FX' },
    { id: 'a3', category: 'TAX', label: 'Tax vault', percentage: 20, targetCurrency: 'USD', sourceAmountMinor: '40000', sourceAmountFormatted: '$400.00', destinationWalletTag: 'Tax', actionType: 'SWEEP_VAULT' },
  ],
  destinationWallets: {},
  explanation: 'split',
  confidenceScore: 1,
  requiresExplicitApproval: true,
} as any;

test('missions - allocations map to legs (HOLD moves nothing)', () => {
  const legs = legsForMission({ title: 't', condition: flagship.triggerCondition, allocations: flagship.allocations }, Date.parse('2026-10-26T00:00:00Z'));
  assert.strictEqual(legs.length, 2);
  assert.deepStrictEqual([legs[0].to, legs[0].destCurrency, legs[0].lockUntil], ['self', 'NGN', undefined]);
  assert.deepStrictEqual([legs[1].to, legs[1].lockUntil], ['self', '2026-11-25T00:00:00.000Z']);
});

test('missions - propose → sign → execute activates with a real hash; other users see nothing', async () => {
  setup();
  MoneyMissionService.resetForTests();
  const proposed = await MoneyMissionService.proposeMission('usr_me', flagship);
  assert.ok(proposed.proposal, 'a money-moving mission needs a signed run');
  assert.deepStrictEqual(ops(proposed.proposal!.signPayload).map((o: any) => o.type), ['pathPaymentStrictSend', 'createClaimableBalance']);

  assert.deepStrictEqual(await MoneyMissionService.listMissions('usr_friend'), []);
  await assert.rejects(MoneyMissionService.prepareRun(proposed.missionId, 'usr_friend'), /not found/);
  await assert.rejects(MoneyMissionService.executeMission({ missionId: proposed.missionId, userId: 'usr_me' }), /sign the prepared run/);

  const done = await MoneyMissionService.executeMission({
    missionId: proposed.missionId,
    userId: 'usr_me',
    proposalId: proposed.proposal!.proposalId,
    signedXdr: sign(proposed.proposal!.signPayload),
  });
  assert.strictEqual(done.status, 'ACTIVE');
  assert.strictEqual(done.transactionHash, proposed.proposal!.proposalId);
  const [listed] = await MoneyMissionService.listMissions('usr_me');
  assert.strictEqual(listed.executionCount, 1);
  assert.strictEqual(listed.lastTransactionHash, done.transactionHash);
});

test('missions - HOLD-only rule activates without any transaction', async () => {
  setup();
  MoneyMissionService.resetForTests();
  const holdOnly = { ...flagship, allocations: [flagship.allocations[0]] };
  holdOnly.allocations[0] = { ...holdOnly.allocations[0], percentage: 100, sourceAmountMinor: '200000' };
  const proposed = await MoneyMissionService.proposeMission('usr_me', holdOnly);
  assert.strictEqual(proposed.proposal, null);
  const done = await MoneyMissionService.executeMission({ missionId: proposed.missionId, userId: 'usr_me' });
  assert.strictEqual(done.transactionHash, null);
  assert.strictEqual(done.status, 'ACTIVE');
});

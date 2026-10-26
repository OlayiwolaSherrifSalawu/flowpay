import test from 'node:test';
import assert from 'node:assert';
import { Account, Keypair, Networks, TransactionBuilder } from '@stellar/stellar-sdk';

const ISSUER = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = ISSUER;

const { StellarHorizon } = await import('../../stellar/horizon.js');
const { PayrollOrchestrationService, setPayrollHorizonForTests } = await import('./service.js');
const { setBatchHorizonForTests } = await import('../payments/batch_service.js');
const { EmployeeService } = await import('../employees/service.js');
const { mailService } = await import('../mail/service.js');
const { registeredUsers } = await import('../../routes/auth.routes.js');
const { linkAccount, resetDirectoryForTests } = await import('../../stellar/directory.js');

(mailService as any).sendEmployeeInvite = async () => ({ success: true });

const employer = Keypair.random();
const line = (code: string, balance: string) => ({ asset_type: 'credit_alphanum4', asset_code: code, asset_issuer: ISSUER, balance });
const all = (o: Record<string, string> = {}) => ['USD', 'CAD', 'MXN', 'GBP', 'NGN'].map((c) => line(c, o[c] ?? '0'));
const httpError = (status: number, data?: unknown) => Object.assign(new Error(`HTTP ${status}`), { response: { status, data } });
const RATE: Record<string, number> = { NGN: 1550, MXN: 17.5, CAD: 1.375, GBP: 0.78, USD: 1 };

function useNetwork(balances: Record<string, any[]>, submit?: (tx: any) => Promise<any>) {
  const h = new StellarHorizon({
    loadAccount: async (id: string) => {
      if (!balances[id]) throw httpError(404);
      return Object.assign(new Account(id, '900'), { balances: balances[id] }) as any;
    },
    submitTransaction: async (tx: any) => (submit ? submit(tx) : { successful: true, hash: Buffer.from(tx.hash()).toString('hex'), ledger: 3 }),
    getTransaction: async () => { throw httpError(404); },
    strictReceivePaths: async (src: any[], dest: any, amt: string) => [
      { sourceAsset: { code: 'USD', issuer: ISSUER }, sourceAmount: ((Number(amt) / RATE[dest.getCode()]) * 1.003).toFixed(7), destinationAmount: amt, path: [] },
    ],
    strictSendPaths: async () => [],
    fetchBaseFee: async () => 100,
  } as any);
  setPayrollHorizonForTests(h);
  setBatchHorizonForTests(h);
}

async function team(n = 0) {
  EmployeeService.resetForTests();
  resetDirectoryForTests();
  registeredUsers.clear();
  registeredUsers.set('usr_boss', { userId: 'usr_boss', fullName: 'Boss', email: 'boss@corp.test', accountType: 'business', country: 'US', phone: '', companyName: 'Corp', kycStatus: 'verified' });
  await linkAccount('usr_boss', employer.publicKey());

  const balances: Record<string, any[]> = { [employer.publicKey()]: [{ asset_type: 'native', balance: '50' }, ...all({ USD: '5000' })] };
  const join = async (first: string, country: string, amountMinor: number, wallet: 'full' | 'no_trust' | 'none') => {
    const email = `${first.toLowerCase()}@x.test`;
    const { inviteToken } = await EmployeeService.createEmployee('usr_boss', { firstName: first, lastName: 'T', email, country, payrollAmountMinor: amountMinor });
    if (wallet === 'none') return;
    const kp = Keypair.random();
    balances[kp.publicKey()] = wallet === 'full' ? [{ asset_type: 'native', balance: '5' }, ...all()] : [{ asset_type: 'native', balance: '5' }];
    registeredUsers.set(`usr_${first}`, { userId: `usr_${first}`, fullName: first, email, accountType: 'personal', country, phone: '', kycStatus: 'verified' });
    await linkAccount(`usr_${first}`, kp.publicKey());
    await EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: `usr_${first}` });
  };
  await join('Ngozi', 'NG', 155_000_000, 'full'); // ₦1,550,000 ≈ $1,000
  await join('Luis', 'MX', 1_750_000, 'no_trust'); // can't receive MXN yet
  await join('Amy', 'US', 100_000, 'none'); // hasn't joined
  for (let i = 0; i < n; i++) await join(`Bulk${i}`, 'US', 100, 'full');
  return balances;
}

const signAs = (kp: Keypair) => (xdr: string) => {
  const tx = TransactionBuilder.fromXDR(xdr, Networks.TESTNET);
  tx.sign(kp);
  return tx.toXDR();
};

test('payroll preview - live quotes; unpayable employees are skipped with reasons', async () => {
  useNetwork(await team());
  const run = await PayrollOrchestrationService.getPreview('usr_boss');
  assert.strictEqual(run.employeeCount, 3);
  assert.strictEqual(run.payableCount, 1);
  const byName = Object.fromEntries(run.items.map((i) => [i.name.split(' ')[0], i]));
  assert.strictEqual(byName.Ngozi.status, 'PENDING');
  assert.strictEqual(byName.Ngozi.usdAmountFormatted, (1000 * 1.003).toFixed(2));
  assert.match(byName.Luis.railValidationMessage, /has not enabled MXN/);
  assert.match(byName.Amy.railValidationMessage, /not accepted/);
  assert.strictEqual(run.batches.length, 1);
  const tx = TransactionBuilder.fromXDR(run.batches[0].signPayload!, Networks.TESTNET) as any;
  assert.deepStrictEqual(tx.operations.map((o: any) => o.type), ['pathPaymentStrictReceive']);
  assert.strictEqual(tx.operations[0].destAmount, '1550000.0000000');
  assert.strictEqual(run.isBalanceSufficient, true);
});

test('payroll preview - insufficient USD means nothing to sign', async () => {
  const balances = await team();
  balances[employer.publicKey()] = [{ asset_type: 'native', balance: '50' }, ...all({ USD: '10' })];
  useNetwork(balances);
  const run = await PayrollOrchestrationService.getPreview('usr_boss');
  assert.strictEqual(run.isBalanceSufficient, false);
  assert.deepStrictEqual(run.batches, []);
  await assert.rejects(PayrollOrchestrationService.executePayroll('usr_boss', run.runId, {}), /does not cover/);
});

test('payroll execute - settles atomically, real hash per paid employee, single submission', async () => {
  useNetwork(await team());
  const run = await PayrollOrchestrationService.getPreview('usr_boss');
  const b = run.batches[0];
  await assert.rejects(PayrollOrchestrationService.executePayroll('usr_other', run.runId, { [b.proposalId]: signAs(employer)(b.signPayload!) }), /not found/);
  const done = await PayrollOrchestrationService.executePayroll('usr_boss', run.runId, { [b.proposalId]: signAs(employer)(b.signPayload!) });
  assert.strictEqual(done.status, 'COMPLETED');
  const ngozi = done.items.find((i) => i.name.startsWith('Ngozi'))!;
  assert.strictEqual(ngozi.status, 'SUCCESS');
  assert.strictEqual(ngozi.transactionHash, b.proposalId);
  assert.strictEqual(done.items.filter((i) => i.status === 'SKIPPED').length, 2);
  assert.ok(done.batches.every((x) => !('signPayload' in x)), 'signed payloads are not echoed back');
  await assert.rejects(PayrollOrchestrationService.executePayroll('usr_boss', run.runId, {}), /already submitted/);
  assert.strictEqual((await PayrollOrchestrationService.listRuns('usr_boss')).length, 1);
});

test('payroll execute - a rejected batch pays nobody in it and says why', async () => {
  useNetwork(await team(), async () => { throw httpError(400, { extras: { result_codes: { transaction: 'tx_failed', operations: ['op_over_source_max'] } } }); });
  const run = await PayrollOrchestrationService.getPreview('usr_boss');
  const b = run.batches[0];
  const done = await PayrollOrchestrationService.executePayroll('usr_boss', run.runId, { [b.proposalId]: signAs(employer)(b.signPayload!) });
  assert.strictEqual(done.status, 'FAILED');
  const ngozi = done.items.find((i) => i.name.startsWith('Ngozi'))!;
  assert.strictEqual(ngozi.status, 'FAILED');
  assert.match(ngozi.error!, /exchange rate moved/);
  assert.strictEqual(ngozi.transactionHash, undefined);
});

test('payroll - more than 100 employees split into several atomic transactions', async () => {
  useNetwork(await team(100));
  const run = await PayrollOrchestrationService.getPreview('usr_boss');
  assert.strictEqual(run.payableCount, 101);
  assert.deepStrictEqual(run.batches.map((b) => b.employeeIds.length), [100, 1]);
  await assert.rejects(PayrollOrchestrationService.executePayroll('usr_boss', run.runId, { [run.batches[0].proposalId]: 'x' }), /must be signed/);
});

import test from 'node:test';
import assert from 'node:assert';
import { Account, Keypair, Networks, Operation, TransactionBuilder, nativeToScVal } from '@stellar/stellar-sdk';

const ISSUER = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = ISSUER;
process.env.STELLAR_PAYROLL_VAULT_ID = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

const { StellarHorizon } = await import('../../stellar/horizon.js');
const { setPayrollHorizonForTests } = await import('./service.js');
const { setBatchHorizonForTests } = await import('../payments/batch_service.js');
const { PayrollGuaranteeService, setGuaranteeVaultForTests } = await import('./guarantee_service.js');
const { PayrollVaultClient, STROOPS_PER_CENT, simplifyContractError } = await import('../../stellar/soroban.js');
const { EmployeeService } = await import('../employees/service.js');
const { mailService } = await import('../mail/service.js');
const { registeredUsers } = await import('../../routes/auth.routes.js');
const { linkAccount, resetDirectoryForTests } = await import('../../stellar/directory.js');

(mailService as any).sendEmployeeInvite = async () => ({ success: true });

const employer = Keypair.random();
const ngozi = Keypair.random();
const line = (code: string) => ({ asset_type: 'credit_alphanum4', asset_code: code, asset_issuer: ISSUER, balance: '0' });
const all = () => ['USD', 'CAD', 'MXN', 'GBP', 'NGN'].map(line);
const RATE: Record<string, number> = { NGN: 1550, MXN: 17.5, CAD: 1.375, GBP: 0.78, USD: 1 };

/** A stand-in transaction so device signing + hash binding work exactly as in production. */
function standIn(source: string): { xdr: string; hash: string; expiresAt: string } {
  const tx = new TransactionBuilder(new Account(source, '7'), { fee: '100', networkPassphrase: Networks.TESTNET })
    .addOperation(Operation.bumpSequence({ bumpTo: String(Date.now()) }))
    .setTimeout(300)
    .build();
  return { xdr: tx.toXDR(), hash: Buffer.from(tx.hash()).toString('hex'), expiresAt: new Date(Date.now() + 300_000).toISOString() };
}

/** In-memory PayrollVault with the contract's rules (the Rust tests cover the real contract). */
class FakeVault extends PayrollVaultClient {
  nextId = 1;
  salaries = new Map<string, bigint>();
  unlock = new Map<number, number>();
  funded: Array<{ account: string; amountCents: bigint }> = [];
  pendingFund: Array<{ account: string; amountCents: bigint }> = [];
  failNextSubmit = false;

  override async buildFund(args: { employer: string; unlockAt: number; entries: Array<{ account: string; amountCents: bigint }> }) {
    this.pendingFund = args.entries;
    this.unlock.set(this.nextId, args.unlockAt);
    return standIn(args.employer);
  }
  override async buildClaim(args: { employee: string; payrollId: number }) {
    return standIn(args.employee);
  }
  override async submit(signedXdr: string) {
    if (this.failNextSubmit) {
      this.failNextSubmit = false;
      throw new Error('The transaction failed on-chain (txFailed).');
    }
    const hash = Buffer.from(TransactionBuilder.fromXDR(signedXdr, Networks.TESTNET).hash()).toString('hex');
    if (this.pendingFund.length) {
      const id = this.nextId++;
      for (const e of this.pendingFund) this.salaries.set(`${id}:${e.account}`, e.amountCents * STROOPS_PER_CENT);
      this.funded = this.pendingFund;
      this.pendingFund = [];
      return { status: 'COMPLETED' as const, hash, returnValue: BigInt(id) };
    }
    // claim: pay the signer
    const signer = (TransactionBuilder.fromXDR(signedXdr, Networks.TESTNET) as any).source as string;
    const key = [...this.salaries.keys()].find((k) => k.endsWith(`:${signer}`))!;
    const amount = this.salaries.get(key)!;
    this.salaries.set(key, 0n);
    return { status: 'COMPLETED' as const, hash, returnValue: amount };
  }
  override async release(args: { payrollId: number; employee: string }) {
    this.salaries.set(`${args.payrollId}:${args.employee}`, 0n);
    return { status: 'COMPLETED' as const, hash: 'f'.repeat(64), returnValue: null };
  }
  override async salaryStroops(payrollId: number, employee: string) {
    return this.salaries.get(`${payrollId}:${employee}`) ?? 0n;
  }
  override async getPayroll(payrollId: number) {
    let remaining = 0n;
    for (const [k, v] of this.salaries) if (k.startsWith(`${payrollId}:`)) remaining += v;
    return { employer: employer.publicKey(), token: 'C', unlockAt: this.unlock.get(payrollId)!, reclaimAfter: 0, totalStroops: 0n, remainingStroops: remaining, employees: [] };
  }
}

async function setup(): Promise<FakeVault> {
  EmployeeService.resetForTests();
  resetDirectoryForTests();
  registeredUsers.clear();
  const balances: Record<string, any[]> = {
    [employer.publicKey()]: [{ asset_type: 'native', balance: '50' }, line('USD'), ...all()],
    [ngozi.publicKey()]: [{ asset_type: 'native', balance: '5' }, ...all()],
  };
  balances[employer.publicKey()][1].balance = '5000';
  const h = new StellarHorizon({
    loadAccount: async (id: string) => Object.assign(new Account(id, '900'), { balances: balances[id] ?? [] }) as any,
    submitTransaction: async () => ({ successful: true, hash: 'x', ledger: 1 }),
    getTransaction: async () => ({}) as any,
    strictReceivePaths: async (_s: any[], dest: any, amt: string) => [
      { sourceAsset: { code: 'USD', issuer: ISSUER }, sourceAmount: (Number(amt) / RATE[dest.getCode()]).toFixed(7), destinationAmount: amt, path: [] },
    ],
    strictSendPaths: async () => [],
    fetchBaseFee: async () => 100,
  } as any);
  setPayrollHorizonForTests(h);
  setBatchHorizonForTests(h);

  registeredUsers.set('usr_boss', { userId: 'usr_boss', fullName: 'Boss', email: 'boss@corp.test', accountType: 'business', country: 'US', phone: '', companyName: 'Corp', kycStatus: 'verified' });
  await linkAccount('usr_boss', employer.publicKey());
  const { inviteToken } = await EmployeeService.createEmployee('usr_boss', { firstName: 'Ngozi', lastName: 'T', email: 'ngozi@x.test', country: 'NG', payrollAmountMinor: 15_500_000 });
  registeredUsers.set('usr_ngozi', { userId: 'usr_ngozi', fullName: 'Ngozi T', email: 'ngozi@x.test', accountType: 'personal', country: 'NG', phone: '', kycStatus: 'verified', emailVerified: true });
  await linkAccount('usr_ngozi', ngozi.publicKey());
  await EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: 'usr_ngozi' });
  await EmployeeService.createEmployee('usr_boss', { firstName: 'Amy', lastName: 'T', email: 'amy@x.test', country: 'US', payrollAmountMinor: 100_000 });

  const vault = new FakeVault(undefined as any, process.env.STELLAR_PAYROLL_VAULT_ID);
  setGuaranteeVaultForTests(vault);
  return vault;
}

const sign = (kp: Keypair, xdr: string) => {
  const tx = TransactionBuilder.fromXDR(xdr, Networks.TESTNET);
  tx.sign(kp);
  return tx.toXDR();
};
const inAWeek = () => new Date(Date.now() + 7 * 864e5).toISOString();

test('guarantee - propose reserves each payable employee’s quoted USD; unjoined are skipped', async () => {
  const vault = await setup();
  const p = await PayrollGuaranteeService.propose('usr_boss', { unlockAt: inAWeek() });
  assert.strictEqual(p.entries.length, 1);
  assert.strictEqual(p.entries[0].account, ngozi.publicKey());
  assert.strictEqual(p.entries[0].amountUsd, '100.00'); // ₦155,000 at 1550
  assert.strictEqual(p.totalUsd, '100.00');
  assert.strictEqual(vault.pendingFund[0].amountCents, 10_000n);
  assert.ok(p.skipped.some((s) => s.name.startsWith('Amy')));
  assert.ok(p.signPayload && p.proposalId);
});

test('guarantee - payday must be in range; a wallet is required', async () => {
  await setup();
  await assert.rejects(PayrollGuaranteeService.propose('usr_boss', { unlockAt: new Date(Date.now() + 5_000).toISOString() }), /at least a minute/);
  await assert.rejects(PayrollGuaranteeService.propose('usr_boss', { unlockAt: new Date(Date.now() + 100 * 864e5).toISOString() }), /90 days/);
  await assert.rejects(PayrollGuaranteeService.propose('usr_boss', { unlockAt: 'soon' }), /ISO/);
  registeredUsers.set('usr_new', { userId: 'usr_new', fullName: 'New', email: 'n@x.test', accountType: 'business', country: 'US', phone: '', kycStatus: 'pending' });
  await assert.rejects(PayrollGuaranteeService.propose('usr_new', { unlockAt: inAWeek() }), /Set up your wallet/);
});

test('guarantee - only the reviewed, employer-signed transaction is accepted; recorded after the ledger confirms', async () => {
  const vault = await setup();
  const p = await PayrollGuaranteeService.propose('usr_boss', { unlockAt: inAWeek() });
  await assert.rejects(PayrollGuaranteeService.execute('usr_ngozi', p.proposalId, sign(employer, p.signPayload)), /not found/);
  const other = standIn(employer.publicKey());
  await assert.rejects(PayrollGuaranteeService.execute('usr_boss', p.proposalId, sign(employer, other.xdr)), /does not match/);

  vault.failNextSubmit = true;
  await assert.rejects(PayrollGuaranteeService.execute('usr_boss', p.proposalId, sign(employer, p.signPayload)), /failed on-chain/);
  assert.deepStrictEqual(await PayrollGuaranteeService.listForEmployer('usr_boss'), [], 'a failed funding records nothing');
  await assert.rejects(PayrollGuaranteeService.execute('usr_boss', p.proposalId, sign(employer, p.signPayload)), /not found/, 'single use');

  const p2 = await PayrollGuaranteeService.propose('usr_boss', { unlockAt: inAWeek() });
  const g = await PayrollGuaranteeService.execute('usr_boss', p2.proposalId, sign(employer, p2.signPayload));
  assert.strictEqual(g.payrollId, 1);
  assert.match(g.explorerUrl, /stellar\.expert\/explorer\/testnet\/tx\//);
  const [listed] = await PayrollGuaranteeService.listForEmployer('usr_boss');
  assert.strictEqual(listed.remainingUsd, '100.00');
  assert.strictEqual(listed.isUnlocked, false);
  assert.deepStrictEqual(await PayrollGuaranteeService.listForEmployer('usr_ngozi'), [], 'employers only see their own');
});

test('guarantee - the employee sees their reserved pay and claims it; no early release', async () => {
  await setup();
  const p = await PayrollGuaranteeService.propose('usr_boss', { unlockAt: inAWeek() });
  const g = await PayrollGuaranteeService.execute('usr_boss', p.proposalId, sign(employer, p.signPayload));

  const [mine] = await PayrollGuaranteeService.listForEmployee('usr_ngozi');
  assert.strictEqual(mine.amountUsd, '100.00');
  assert.strictEqual(mine.paid, false);
  assert.strictEqual(mine.coversFormatted, '155,000.00 NGN');
  await assert.rejects(PayrollGuaranteeService.releaseAll('usr_boss', g.payrollId), /isn't payday/);
  await assert.rejects(PayrollGuaranteeService.releaseAll('usr_ngozi', g.payrollId), /not found/);

  const c = await PayrollGuaranteeService.proposeClaim('usr_ngozi', g.payrollId);
  await assert.rejects(PayrollGuaranteeService.executeClaim('usr_boss', c.proposalId, sign(ngozi, c.signPayload)), /not found/);
  const done = await PayrollGuaranteeService.executeClaim('usr_ngozi', c.proposalId, sign(ngozi, c.signPayload));
  assert.strictEqual(done.amountUsd, '100.00');
  assert.strictEqual((await PayrollGuaranteeService.listForEmployee('usr_ngozi'))[0].paid, true);
});

test('soroban client - COMPLETED only on SUCCESS; FAILED surfaces; unconfirmed is PENDING', async () => {
  const tx = standIn(employer.publicKey());
  const gw = (statuses: string[], send = 'PENDING') => ({
    loadAccount: async (id: string) => new Account(id, '1'),
    prepare: async (t: any) => t,
    read: async () => nativeToScVal(0),
    send: async () => ({ status: send as any, hash: tx.hash, errorDetail: send === 'ERROR' ? 'txBadSeq' : undefined }),
    getStatus: async () => {
      const s = statuses.shift() ?? 'NOT_FOUND';
      return { status: s as any, returnValue: s === 'SUCCESS' ? nativeToScVal(7, { type: 'u64' }) : undefined, errorDetail: s === 'FAILED' ? 'txFailed' : undefined };
    },
  });
  const ok = await new PayrollVaultClient(gw(['NOT_FOUND', 'SUCCESS']), 'C', 0, 5).submit(tx.xdr);
  assert.deepStrictEqual([ok.status, ok.hash, ok.returnValue], ['COMPLETED', tx.hash, 7n]);
  await assert.rejects(new PayrollVaultClient(gw(['FAILED']), 'C', 0, 5).submit(tx.xdr), /failed on-chain \(txFailed\)/);
  await assert.rejects(new PayrollVaultClient(gw([], 'ERROR'), 'C', 0, 5).submit(tx.xdr), /rejected the transaction \(txBadSeq\)/);
  await assert.rejects(new PayrollVaultClient(gw([]), 'C', 0, 3).submit(tx.xdr), (e: any) => e.code === 'STELLAR_SUBMIT_PENDING' && e.hash === tx.hash);
});

test('soroban client - contract error codes become plain language', () => {
  assert.strictEqual(simplifyContractError('HostError: Error(Contract, #7)\n...'), "it isn't payday yet");
  assert.strictEqual(simplifyContractError(new Error('Error(Contract, #9)')), 'unclaimed salaries can only be reclaimed 30 days after payday');
  assert.strictEqual(simplifyContractError('resulting balance is not within the allowed range'), 'not enough USD in the paying account');
});

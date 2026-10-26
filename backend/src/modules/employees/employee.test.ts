import test from 'node:test';
import assert from 'node:assert';
import { Keypair } from '@stellar/stellar-sdk';

process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = Keypair.random().publicKey();

const { EmployeeService, hashInviteToken } = await import('./service.js');
const { mailService } = await import('../mail/service.js');
const { registeredUsers } = await import('../../routes/auth.routes.js');
const { linkAccount, resetDirectoryForTests } = await import('../../stellar/directory.js');

// No real email in tests.
(mailService as any).sendEmployeeInvite = async () => ({ success: true, messageId: 'test' });

const base = { firstName: 'Ada', lastName: 'Obi', email: 'ada@example.com', country: 'NG', payrollAmountMinor: 50_000_000 };

function reset() {
  EmployeeService.resetForTests();
  resetDirectoryForTests();
  registeredUsers.clear();
  registeredUsers.set('usr_employer_a', { userId: 'usr_employer_a', fullName: 'Boss A', email: 'a@corp.test', accountType: 'business', country: 'US', phone: '', companyName: 'Corp A', kycStatus: 'verified' });
  registeredUsers.set('usr_employer_b', { userId: 'usr_employer_b', fullName: 'Boss B', email: 'b@corp.test', accountType: 'business', country: 'US', phone: '', companyName: 'Corp B', kycStatus: 'verified' });
}

// ── validation ───────────────────────────────────────────────────────────────

test('employees - validation accepts the five supported countries and rejects bad input', () => {
  for (const country of ['US', 'CA', 'MX', 'GB', 'NG']) {
    assert.strictEqual(EmployeeService.validateCreateInput({ ...base, country }).valid, true, country);
  }
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, country: 'FR' }).valid, false);
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, email: 'nope' }).valid, false);
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, firstName: '  ' }).valid, false);
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, payrollAmountMinor: 0 }).valid, false);
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, payrollAmountMinor: 10.5 }).valid, false);
  assert.strictEqual(EmployeeService.validateCreateInput({ ...base, targetCurrency: 'EUR' }).valid, false);
  assert.deepStrictEqual(['US', 'CA', 'MX', 'GB', 'NG'].map((c) => EmployeeService.resolveCurrency(c)), ['USD', 'CAD', 'MXN', 'GBP', 'NGN']);
});

// ── creation & scoping ───────────────────────────────────────────────────────

test('employees - create stores only the invite token HASH; employers only see their own team', async () => {
  reset();
  const { employee, inviteToken, inviteUrl } = await EmployeeService.createEmployee('usr_employer_a', base);
  assert.strictEqual(employee.status, 'INVITED');
  assert.match(inviteToken, /^[0-9a-f]{48}$/);
  assert.strictEqual(employee.inviteTokenHash, hashInviteToken(inviteToken));
  assert.ok(!JSON.stringify(employee).includes(inviteToken), 'plaintext token is never on the record');
  assert.ok(inviteUrl.endsWith(`/invite/${inviteToken}`));

  assert.strictEqual((await EmployeeService.listEmployees('usr_employer_a')).length, 1);
  assert.deepStrictEqual(await EmployeeService.listEmployees('usr_employer_b'), []);
  await assert.rejects(EmployeeService.getEmployee('usr_employer_b', employee.id), /not found/);
  await assert.rejects(EmployeeService.createEmployee('usr_employer_a', base), /already on your team/);
});

// ── invites ──────────────────────────────────────────────────────────────────

test('invites - resolve by token only; email or employee id never yields an invite', async () => {
  reset();
  const { employee, inviteToken } = await EmployeeService.createEmployee('usr_employer_a', base);
  const invite = await EmployeeService.getInviteDetails(inviteToken);
  assert.strictEqual(invite.email, 'ada@example.com');
  assert.strictEqual(invite.companyName, 'Corp A');
  await assert.rejects(EmployeeService.getInviteDetails('ada@example.com'), /not valid/);
  await assert.rejects(EmployeeService.getInviteDetails(employee.id), /not valid/);
});

test('invites - accept requires matching email AND a proven wallet; then single use', async () => {
  reset();
  const { inviteToken } = await EmployeeService.createEmployee('usr_employer_a', base);
  const wallet = Keypair.random().publicKey();

  registeredUsers.set('usr_imposter', { userId: 'usr_imposter', fullName: 'X', email: 'x@evil.test', accountType: 'personal', country: 'NG', phone: '', kycStatus: 'verified' });
  await linkAccount('usr_imposter', Keypair.random().publicKey());
  await assert.rejects(EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: 'usr_imposter' }), (e: any) => e.statusCode === 403);

  registeredUsers.set('usr_ada', { userId: 'usr_ada', fullName: 'Ada Obi', email: 'ADA@example.com', accountType: 'personal', country: 'NG', phone: '', kycStatus: 'verified' });
  await assert.rejects(EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: 'usr_ada' }), /activate your wallet first/);

  await linkAccount('usr_ada', wallet);
  const joined = await EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: 'usr_ada' });
  assert.strictEqual(joined.status, 'READY');
  assert.strictEqual(joined.walletAddress, wallet);
  assert.strictEqual(joined.linkedUserId, 'usr_ada');
  await assert.rejects(EmployeeService.acceptInvite({ token: inviteToken, requestingUserId: 'usr_ada' }), /not valid/);
});

test('invites - resend invalidates the old link; expired links are refused', async () => {
  reset();
  const { employee, inviteToken } = await EmployeeService.createEmployee('usr_employer_a', base);
  const fresh = await EmployeeService.resendInvite('usr_employer_a', employee.id);
  await assert.rejects(EmployeeService.getInviteDetails(inviteToken), /not valid/);
  assert.strictEqual((await EmployeeService.getInviteDetails(fresh.inviteToken)).employeeId, employee.id);

  const rec = await EmployeeService.getEmployee('usr_employer_a', employee.id);
  rec.inviteExpiresAt = new Date(Date.now() - 1000);
  await assert.rejects(EmployeeService.getInviteDetails(fresh.inviteToken), (e: any) => e.code === 'EXPIRED');
});

test('employees - status changes are constrained (no READY without a wallet)', async () => {
  reset();
  const { employee } = await EmployeeService.createEmployee('usr_employer_a', base);
  await assert.rejects(EmployeeService.updateEmployee('usr_employer_a', employee.id, { status: 'READY' }), /Can't move/);
  const suspended = await EmployeeService.updateEmployee('usr_employer_a', employee.id, { status: 'SUSPENDED' });
  assert.strictEqual(suspended.status, 'SUSPENDED');
  await assert.rejects(EmployeeService.updateEmployee('usr_employer_b', employee.id, { status: 'SUSPENDED' }), /not found/);
});

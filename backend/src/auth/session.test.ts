import test from 'node:test';
import assert from 'node:assert';
import { Keypair } from '@stellar/stellar-sdk';
import { issueSessionToken, verifySessionToken, requireAuth, authedUserId, SESSION_TTL_SECONDS } from './session.js';
import { issueOwnershipChallenge, verifyOwnershipChallenge } from '../stellar/challenge.js';

test('session - issued tokens verify to their user', () => {
  const t = issueSessionToken('usr_a');
  assert.strictEqual(verifySessionToken(t).userId, 'usr_a');
});

test('session - tampered, forged and expired tokens are rejected', () => {
  const t = issueSessionToken('usr_a');
  const [h, p, s] = t.split('.');
  const forgedPayload = Buffer.from(JSON.stringify({ sub: 'usr_victim', iat: 0, exp: 9e9, iss: 'flowpay' })).toString('base64url');
  assert.throws(() => verifySessionToken(`${h}.${forgedPayload}.${s}`), /Invalid session/);
  assert.throws(() => verifySessionToken(`${h}.${p}.${s.slice(0, -2)}xx`), /Invalid session/);
  assert.throws(() => verifySessionToken('flowpay_jwt_usr_a_123'), /Invalid session/, 'old fake tokens are not accepted');
  const old = issueSessionToken('usr_a', 1000);
  assert.throws(() => verifySessionToken(old, 1000 + SESSION_TTL_SECONDS + 1), /expired/);
});

test('requireAuth - identity comes only from the bearer token, never headers', () => {
  const req: any = { headers: { 'x-user-id': 'usr_victim' } };
  let err: any;
  requireAuth(req, {} as any, (e?: any) => (err = e));
  assert.match(String(err), /Sign in required/);

  const ok: any = { headers: { authorization: `Bearer ${issueSessionToken('usr_me')}`, 'x-user-id': 'usr_victim' } };
  requireAuth(ok, {} as any, (e?: any) => (err = e));
  assert.strictEqual(err, undefined);
  assert.strictEqual(authedUserId(ok), 'usr_me');
});

test('login challenge - must be signed by the wallet key it names', () => {
  const kp = Keypair.random();
  const c = issueOwnershipChallenge(kp.publicKey(), 'login');
  const wrong = Buffer.from(Keypair.random().sign(Buffer.from(c.message, 'utf8'))).toString('hex');
  assert.throws(() => verifyOwnershipChallenge({ message: c.message, signatureHex: wrong, accountId: kp.publicKey(), userId: 'login' }));
  const right = Buffer.from(kp.sign(Buffer.from(c.message, 'utf8'))).toString('hex');
  assert.doesNotThrow(() => verifyOwnershipChallenge({ message: c.message, signatureHex: right, accountId: kp.publicKey(), userId: 'login' }));
});

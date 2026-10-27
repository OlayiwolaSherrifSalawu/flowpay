import test from 'node:test';
import assert from 'node:assert';
import { Keypair } from '@stellar/stellar-sdk';

const issuer = Keypair.random().publicKey();
process.env.STELLAR_NETWORK = 'testnet';
process.env.STELLAR_ASSET_ISSUER = issuer;
process.env.STELLAR_ASSET_GBP = `USDC:${Keypair.random().publicKey()}`; // a third-party asset
process.env.FLOWPAY_HOME_DOMAIN = 'pay.flowpay.test';

const fed = await import('./federation.js');
const { registeredUsers } = await import('../routes/auth.routes.js');
const { linkAccount, resetDirectoryForTests, resolveRecipient } = await import('./directory.js');

const DOMAIN = 'pay.flowpay.test';
const adaAccount = Keypair.random().publicKey();

async function reset() {
  fed.resetFederationForTests();
  resetDirectoryForTests();
  registeredUsers.clear();
  registeredUsers.set('usr_ada', { userId: 'usr_ada', fullName: 'Ada Okafor', email: 'ada@example.com', accountType: 'personal', country: 'NG', phone: '', kycStatus: 'pending' });
  registeredUsers.set('usr_ben', { userId: 'usr_ben', fullName: 'Ben Cole', email: 'ben@example.com', accountType: 'personal', country: 'GB', phone: '', kycStatus: 'pending' });
  await linkAccount('usr_ada', adaAccount);
}

test('federation - names are validated, reserved names refused', () => {
  assert.strictEqual(fed.normalizeHandle('  Ada.Okafor '), 'ada.okafor');
  for (const bad of ['ab', '-ada', 'ada*x', 'ada okafor', 'a'.repeat(33), 'admin', 'flowpay']) {
    assert.throws(() => fed.normalizeHandle(bad), Error, bad);
  }
});

test('federation - claiming requires a wallet and a free name; changing frees the old one', async () => {
  await reset();
  await assert.rejects(fed.claimHandle('usr_ben', 'ben'), /Set up your wallet/);
  assert.strictEqual(await fed.claimHandle('usr_ada', 'Ada'), 'ada');
  await linkAccount('usr_ben', Keypair.random().publicKey());
  await assert.rejects(fed.claimHandle('usr_ben', 'ada'), /already taken/);

  await fed.claimHandle('usr_ada', 'ada.okafor');
  await assert.rejects(fed.federationByName(`ada*${DOMAIN}`, DOMAIN), /No account/);
  assert.strictEqual(await fed.claimHandle('usr_ben', 'ada'), 'ada', 'released name can be claimed');
});

test('federation - SEP-2 name and id lookups answer only for claimed names on our domain', async () => {
  await reset();
  // Unclaimed: neither the email nor the account is discoverable.
  await assert.rejects(fed.federationByName(`ada@example.com*${DOMAIN}`, DOMAIN), /No account/);
  await assert.rejects(fed.federationById(adaAccount, DOMAIN), /No public name/);

  await fed.claimHandle('usr_ada', 'ada');
  assert.deepStrictEqual(await fed.federationByName(`ADA*${DOMAIN}`, DOMAIN), { stellar_address: `ada*${DOMAIN}`, account_id: adaAccount });
  assert.deepStrictEqual(await fed.federationById(adaAccount, DOMAIN), { stellar_address: `ada*${DOMAIN}`, account_id: adaAccount });
  await assert.rejects(fed.federationByName('ada*other.example', DOMAIN), /not served/);
  await assert.rejects(fed.federationByName('ada', DOMAIN), /name\*domain/);
});

test('federation - our own names resolve locally when sending', async () => {
  await reset();
  await fed.claimHandle('usr_ada', 'ada');
  const r = await resolveRecipient(`ada*${DOMAIN}`);
  assert.strictEqual(r.accountId, adaAccount);
  assert.strictEqual(r.userId, 'usr_ada');
  assert.strictEqual(r.source, 'federation');
  await assert.rejects(resolveRecipient(`nobody*${DOMAIN}`), /No account/);
});

test('stellar.toml - publishes federation server and ONLY FlowPay-issued assets', () => {
  const toml = fed.buildStellarToml(DOMAIN);
  assert.match(toml, /NETWORK_PASSPHRASE = "Test SDF Network ; September 2015"/);
  assert.match(toml, new RegExp(`FEDERATION_SERVER = "https://${DOMAIN.replace(/\./g, '\\.')}/federation"`));
  assert.match(toml.split('\n').find((l) => l.startsWith('ACCOUNTS = ')) ?? '', new RegExp(issuer));
  for (const code of ['USD', 'CAD', 'MXN', 'NGN']) assert.ok(toml.includes(`code = "${code}"`), code);
  assert.ok(!toml.includes('code = "USDC"'), 'third-party asset is never described as ours');
  assert.match(toml, /status = "test"/);
  assert.ok(!/secret|S[A-Z2-7]{55}/.test(toml), 'no secrets');
});

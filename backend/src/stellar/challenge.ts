import crypto from 'node:crypto';
import { Keypair } from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { InvalidRequestError, UnauthorizedError } from '../core/errors.js';
import { assertAccountId } from './accounts.js';

/**
 * Proof that a device controls a Stellar key: the server issues a short-lived,
 * HMAC-protected message; the device signs it with the account's ed25519 key;
 * the server verifies the signature against the account ID. Single use.
 */

const TTL_MS = 5 * 60 * 1000;
const usedNonces = new Map<string, number>(); // nonce -> expiry ms

export interface OwnershipChallenge {
  message: string;
  expiresAt: string;
}

function mac(body: string): string {
  return crypto.createHmac('sha256', env.FLOWPAY_JWT_SECRET).update(body).digest('hex');
}

export function issueOwnershipChallenge(accountId: string, userId: string, now = Date.now()): OwnershipChallenge {
  assertAccountId(accountId);
  const expiresAt = new Date(now + TTL_MS).toISOString();
  const nonce = crypto.randomBytes(16).toString('hex');
  const body = `FlowPay wallet ownership\naccount:${accountId}\nuser:${userId}\nnonce:${nonce}\nexpires:${expiresAt}`;
  return { message: `${body}\nmac:${mac(body)}`, expiresAt };
}

/**
 * Verifies a signed challenge. Throws UnauthorizedError on any mismatch; returns the
 * verified { accountId, userId } on success.
 */
export function verifyOwnershipChallenge(args: {
  message: string;
  signatureHex: string;
  accountId: string;
  userId: string;
  now?: number;
}): { accountId: string; userId: string } {
  const now = args.now ?? Date.now();
  assertAccountId(args.accountId);
  const lines = args.message.split('\n');
  const field = (name: string) => lines.find((l) => l.startsWith(`${name}:`))?.slice(name.length + 1);
  const macLine = field('mac');
  const body = lines.filter((l) => !l.startsWith('mac:')).join('\n');

  if (!macLine || !crypto.timingSafeEqual(Buffer.from(macLine, 'hex'), Buffer.from(mac(body), 'hex'))) {
    throw new UnauthorizedError('Ownership challenge was not issued by FlowPay.');
  }
  if (field('account') !== args.accountId || field('user') !== args.userId) {
    throw new UnauthorizedError('Ownership challenge does not match this account or user.');
  }
  const expires = Date.parse(field('expires') ?? '');
  if (!Number.isFinite(expires) || expires < now) {
    throw new UnauthorizedError('Ownership challenge expired. Request a new one.');
  }
  const nonce = field('nonce')!;
  for (const [n, exp] of usedNonces) if (exp < now) usedNonces.delete(n);
  if (usedNonces.has(nonce)) throw new UnauthorizedError('Ownership challenge was already used.');

  if (!/^[0-9a-f]{128}$/i.test(args.signatureHex)) {
    throw new InvalidRequestError('signature must be a 64-byte ed25519 signature in hex.');
  }
  const ok = Keypair.fromPublicKey(args.accountId).verify(Buffer.from(args.message, 'utf8'), Buffer.from(args.signatureHex, 'hex'));
  if (!ok) throw new UnauthorizedError('Signature does not match this Stellar account.');

  usedNonces.set(nonce, expires);
  return { accountId: args.accountId, userId: args.userId };
}

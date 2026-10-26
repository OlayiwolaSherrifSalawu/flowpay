import { Federation, StrKey } from '@stellar/stellar-sdk';
import { InvalidRequestError, NotFoundError } from '../core/errors.js';
import { isPostgresDb, prisma } from '../db/index.js';
import { registeredUsers, type RegisteredUser } from '../routes/auth.routes.js';

/**
 * Maps FlowPay users ↔ the Stellar accounts they proved they own, and resolves
 * payment recipients STRICTLY. Money never goes to a fuzzy match.
 */

export interface ResolvedRecipient {
  accountId: string;
  /** FlowPay user behind the account, when there is one. */
  userId?: string;
  displayName: string;
  /** Memo required by the destination (e.g. an exchange via federation). */
  memo?: { type: 'text' | 'id'; value: string };
  source: 'account_id' | 'flowpay_user' | 'federation';
}

const accountByUser = new Map<string, string>();

export async function linkAccount(userId: string, accountId: string): Promise<void> {
  if (isPostgresDb()) {
    const holder = await prisma.user.findFirst({ where: { stellarAccountId: accountId } });
    if (holder && holder.id !== userId) {
      throw new InvalidRequestError('This Stellar account is already linked to another FlowPay user.');
    }
    await prisma.user.update({ where: { id: userId }, data: { stellarAccountId: accountId } });
  } else {
    for (const [uid, acc] of accountByUser) {
      if (acc === accountId && uid !== userId) {
        throw new InvalidRequestError('This Stellar account is already linked to another FlowPay user.');
      }
    }
  }
  accountByUser.set(userId, accountId);
  const mem = registeredUsers.get(userId);
  if (mem) mem.stellarAccountId = accountId;
}

export async function accountForUser(userId: string): Promise<string | null> {
  if (accountByUser.has(userId)) return accountByUser.get(userId)!;
  if (isPostgresDb()) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (user?.stellarAccountId) {
      accountByUser.set(userId, user.stellarAccountId);
      return user.stellarAccountId;
    }
  }
  return registeredUsers.get(userId)?.stellarAccountId ?? null;
}

export async function userForAccount(accountId: string): Promise<{ userId: string; fullName: string } | null> {
  for (const [uid, acc] of accountByUser) {
    if (acc === accountId) {
      const mem = registeredUsers.get(uid);
      return { userId: uid, fullName: mem?.fullName ?? uid };
    }
  }
  if (isPostgresDb()) {
    const user = await prisma.user.findFirst({ where: { stellarAccountId: accountId } });
    if (user) return { userId: user.id, fullName: user.fullName };
  }
  return null;
}

/** Testing hook. */
export function resetDirectoryForTests(): void {
  accountByUser.clear();
}

function normalizePhone(p: string): string {
  return p.replace(/[^0-9+]/g, '');
}

/**
 * Exact-match user search: email, phone, user ID, or FULL name. A full-name query that
 * matches more than one user is rejected as ambiguous.
 */
async function findUsersExact(query: string): Promise<Array<Pick<RegisteredUser, 'userId' | 'fullName'>>> {
  const q = query.trim();
  const lower = q.toLowerCase();
  const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(q);
  const isPhone = /^\+?[0-9][0-9\s-]{6,}$/.test(q);
  const matches = new Map<string, Pick<RegisteredUser, 'userId' | 'fullName'>>();

  for (const u of registeredUsers.values()) {
    const hit = isEmail
      ? u.email.toLowerCase() === lower
      : isPhone
        ? !!u.phone && normalizePhone(u.phone) === normalizePhone(q)
        : u.userId === q || u.fullName.toLowerCase() === lower;
    if (hit) matches.set(u.userId, { userId: u.userId, fullName: u.fullName });
  }

  if (isPostgresDb()) {
    const where = isEmail
      ? { email: { equals: q, mode: 'insensitive' as const } }
      : isPhone
        ? { phoneNumber: normalizePhone(q) }
        : { OR: [{ id: q }, { fullName: { equals: q, mode: 'insensitive' as const } }] };
    const rows = await prisma.user.findMany({ where, take: 5 });
    for (const r of rows) matches.set(r.id, { userId: r.id, fullName: r.fullName });
  }
  return [...matches.values()];
}

export async function resolveRecipient(query: string): Promise<ResolvedRecipient> {
  const q = (query ?? '').trim();
  if (!q) throw new InvalidRequestError('Recipient is required.');

  if (StrKey.isValidEd25519PublicKey(q)) {
    const owner = await userForAccount(q);
    return { accountId: q, userId: owner?.userId, displayName: owner?.fullName ?? `${q.slice(0, 4)}…${q.slice(-4)}`, source: 'account_id' };
  }

  if (/^[^*\s]+\*[^*\s]+\.[^*\s]+$/.test(q)) {
    // Our own payment names resolve locally (no HTTP round-trip to ourselves).
    const { federationByName, homeDomainFor } = await import('./federation.js');
    const ownDomain = homeDomainFor();
    if (ownDomain && q.split('*')[1].toLowerCase() === ownDomain) {
      const rec = await federationByName(q, ownDomain);
      const owner = await userForAccount(rec.account_id);
      return { accountId: rec.account_id, userId: owner?.userId, displayName: owner?.fullName ?? rec.stellar_address, source: 'federation' };
    }
    try {
      const rec = await Federation.Server.resolve(q);
      const memo = rec.memo ? { type: (rec.memo_type === 'id' ? 'id' : 'text') as 'id' | 'text', value: String(rec.memo) } : undefined;
      return { accountId: rec.account_id, displayName: q, memo, source: 'federation' };
    } catch (err) {
      throw new NotFoundError(`Could not resolve Stellar address ${q}: ${(err as Error).message}`);
    }
  }

  const users = await findUsersExact(q);
  if (users.length === 0) {
    throw new NotFoundError(
      `No FlowPay user matches "${q}". Use their exact email, phone number, or Stellar account ID (G...).`
    );
  }
  if (users.length > 1) {
    throw new InvalidRequestError(`"${q}" matches more than one FlowPay user. Use their email or phone number instead.`);
  }
  const accountId = await accountForUser(users[0].userId);
  if (!accountId) {
    throw new InvalidRequestError(`${users[0].fullName} has not set up their FlowPay wallet yet.`);
  }
  return { accountId, userId: users[0].userId, displayName: users[0].fullName, source: 'flowpay_user' };
}

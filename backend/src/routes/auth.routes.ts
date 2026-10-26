import { env } from '../config/env.js';
import crypto, { randomUUID } from 'node:crypto';
import { authedUserId, issueSessionToken, requireAuth } from '../auth/session.js';
import { InvalidRequestError, UnauthorizedError } from '../core/errors.js';
import { mailService } from '../modules/mail/service.js';
import { issueOwnershipChallenge, verifyOwnershipChallenge } from '../stellar/challenge.js';
import { userForAccount } from '../stellar/directory.js';
import { Router } from 'express';
import { prisma, isPostgresDb } from '../db/index.js';

export const authRouter = Router();

export interface RegisteredUser {
  userId: string;
  fullName: string;
  email: string;
  accountType: 'personal' | 'business' | 'both';
  country: string;
  phone: string;
  companyName?: string;
  companyRole?: string;
  kycStatus: 'unverified' | 'pending' | 'verified';
  nationalId?: string;
  stellarAccountId?: string;
  emailVerified?: boolean;
}

export const registeredUsers = new Map<string, RegisteredUser>();


function fromDbUser(dbUser: any): RegisteredUser {
  return {
    userId: dbUser.id,
    fullName: dbUser.fullName,
    email: dbUser.email,
    accountType: dbUser.accountType,
    country: dbUser.country,
    phone: dbUser.phoneNumber || '',
    companyName: dbUser.companyName || undefined,
    companyRole: dbUser.companyRole || undefined,
    kycStatus: dbUser.kycStatus,
    nationalId: dbUser.nationalId || undefined,
    stellarAccountId: dbUser.stellarAccountId || undefined,
    emailVerified: !!dbUser.emailVerified,
  };
}

/** Exact lookup by user ID (memory first, then Postgres). */
export async function loadUser(userId: string): Promise<RegisteredUser | undefined> {
  const mem = registeredUsers.get(userId);
  if (mem) return mem;
  if (isPostgresDb()) {
    const dbUser = await prisma.user.findUnique({ where: { id: userId } });
    if (dbUser) {
      const user = fromDbUser(dbUser);
      registeredUsers.set(user.userId, user);
      return user;
    }
  }
  return undefined;
}

/** Exact, case-insensitive lookup by email. */
export async function findUserByEmail(email: string): Promise<RegisteredUser | undefined> {
  const clean = email.trim().toLowerCase();
  for (const u of registeredUsers.values()) if (u.email.toLowerCase() === clean) return u;
  if (isPostgresDb()) {
    const dbUser = await prisma.user.findFirst({ where: { email: { equals: clean, mode: 'insensitive' } } });
    if (dbUser) {
      const user = fromDbUser(dbUser);
      registeredUsers.set(user.userId, user);
      return user;
    }
  }
  return undefined;
}

async function resolveCapabilities(newUserId: string) {
  let user = registeredUsers.get(newUserId);

  // Attempt database query from public.users
  if (isPostgresDb()) {
    try {
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [{ id: newUserId }],
        },
      });
      if (dbUser) {
        user = {
          userId: dbUser.id,
          fullName: dbUser.fullName,
          email: dbUser.email,
          accountType: dbUser.accountType as any,
          country: dbUser.country,
          phone: dbUser.phoneNumber || '',
          companyName: dbUser.companyName || undefined,
          companyRole: dbUser.companyRole || undefined,
          kycStatus: dbUser.kycStatus as any,
          nationalId: dbUser.nationalId || undefined,
        };
        registeredUsers.set(newUserId, user);
      }
    } catch (_) {
      // Non-blocking fallback to in-memory
    }
  }

  const isPersonal = user ? user.accountType === 'personal' : newUserId.includes('personal');
  const isBusiness = user ? user.accountType === 'business' : newUserId.includes('business');
  const isMaster = user?.accountType === 'both';

  if (isMaster) {
    return {
      userId: newUserId,
      hasPersonalWallet: true,
      hasBusinessAccess: true,
      company: {
        companyId: 'comp_flowpay_global',
        name: user?.companyName || 'FlowPay Technologies Ltd',
        role: user?.companyRole || 'ADMIN',
      },
      capabilities: ['PERSONAL_WALLET', 'BUSINESS_PAYROLL', 'MULTI_COUNTRY_SETTLEMENT'],
      cachedAt: new Date().toISOString(),
    };
  }

  if (isPersonal) {
    return {
      userId: newUserId,
      hasPersonalWallet: true,
      hasBusinessAccess: false,
      capabilities: ['PERSONAL_WALLET', 'MONEY_MISSIONS'],
      cachedAt: new Date().toISOString(),
    };
  }

  return {
    userId: newUserId,
    hasPersonalWallet: false,
    hasBusinessAccess: true,
    company: {
      companyId: `comp_${newUserId}`,
      name: user?.companyName || 'FlowPay Business Ltd',
      role: user?.companyRole || 'ADMIN',
    },
    capabilities: ['BUSINESS_PAYROLL', 'MULTI_COUNTRY_SETTLEMENT'],
    cachedAt: new Date().toISOString(),
  };
}

/**
 * GET /api/auth/session
 * Returns active session context for the authenticated mobile client.
 */
authRouter.get('/session', requireAuth, async (req, res) => {
  const userId = authedUserId(req);

  let user: RegisteredUser | undefined = registeredUsers.get(userId);

  if (isPostgresDb() && !user) {
    try {
      const dbUser = await prisma.user.findFirst({
        where: { id: userId },
      });
      if (dbUser) {
        user = {
          userId: dbUser.id,
          fullName: dbUser.fullName,
          email: dbUser.email,
          accountType: dbUser.accountType as any,
          country: dbUser.country,
          phone: dbUser.phoneNumber || '',
          companyName: dbUser.companyName || undefined,
          companyRole: dbUser.companyRole || undefined,
          kycStatus: dbUser.kycStatus as any,
          nationalId: dbUser.nationalId || undefined,
        };
        registeredUsers.set(userId, user);
      }
    } catch (_) {}
  }

  if (!user) {
    return res.status(401).json({
      authenticated: false,
      message: 'Invalid session or user not found.',
    });
  }

  const capabilities = await resolveCapabilities(user.userId);

  res.json({
    authenticated: true,
    user,
    capabilities,
  });
});

/**
 * POST /api/auth/challenge { accountId } → message the device signs with its Stellar key.
 * POST /api/auth/login { accountId, message, signature } → session token.
 *
 * Login proves control of the wallet key (SEP-10 style). The PIN never leaves the
 * device; there is no password to steal or brute-force on the server.
 */
authRouter.post('/challenge', (req, res, next) => {
  try {
    res.json({ success: true, data: issueOwnershipChallenge(String(req.body?.accountId ?? ''), 'login') });
  } catch (err) {
    next(err);
  }
});

authRouter.post('/login', async (req, res, next) => {
  try {
    const { accountId, message, signature } = req.body ?? {};
    if (typeof accountId !== 'string' || typeof message !== 'string' || typeof signature !== 'string') {
      throw new InvalidRequestError('accountId, message and signature are required. Sign in with your wallet.');
    }
    verifyOwnershipChallenge({ message, signatureHex: signature, accountId, userId: 'login' });
    const owner = await userForAccount(accountId);
    if (!owner) throw new UnauthorizedError('No FlowPay account is linked to this wallet.');
    const user = await loadUser(owner.userId);
    if (!user) throw new UnauthorizedError('No FlowPay account is linked to this wallet.');
    res.json({ success: true, user, capabilities: await resolveCapabilities(user.userId), token: issueSessionToken(user.userId) });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/auth/signup
 * Registers a new Personal or Business account with dedicated capabilities.
 * Persists in Postgres public.users when connected.
 */
authRouter.post('/signup', async (req, res) => {
  const { fullName, email, accountType, country, phone, companyName, companyRole } = req.body;
  if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    return res.status(400).json({ success: false, message: 'A valid email is required.' });
  }
  if (await findUserByEmail(email)) {
    return res.status(409).json({ success: false, code: 'EMAIL_IN_USE', message: 'An account with this email already exists. Sign in with your wallet instead.' });
  }
  // IDs are always generated here — never chosen by the client.
  const newUserId = `usr_${accountType === 'business' ? 'business' : 'personal'}_${randomUUID()}`;

  const user: RegisteredUser = {
    userId: newUserId,
    fullName: fullName || 'FlowPay User',
    email: email.trim().toLowerCase(),
    accountType: accountType === 'business' ? 'business' : 'personal',
    country: country || 'NG',
    phone: phone || '',
    companyName: accountType === 'business' ? (companyName || 'Business Entity') : undefined,
    companyRole: accountType === 'business' ? (companyRole || 'ADMIN') : undefined,
    kycStatus: 'unverified',
  };

  registeredUsers.set(newUserId, user);

  // Persist into Supabase public.users and public.businesses
  if (isPostgresDb()) {
    try {
      await prisma.user.upsert({
        where: { id: newUserId },
        create: {
          id: newUserId,
          email: user.email,
          fullName: user.fullName,
          phoneNumber: user.phone || null,
          accountType: user.accountType,
          country: user.country,
          companyName: user.companyName || null,
          companyRole: user.companyRole || 'ADMIN',
          kycStatus: user.kycStatus,
        },
        update: {
          email: user.email,
          fullName: user.fullName,
          phoneNumber: user.phone || null,
          accountType: user.accountType,
          country: user.country,
          companyName: user.companyName || null,
          companyRole: user.companyRole || 'ADMIN',
        },
      });

      if (user.accountType === 'business' || user.accountType === 'both') {
        const businessId = `biz_${newUserId}`;
        await prisma.business.upsert({
          where: { id: businessId },
          create: {
            id: businessId,
            ownerUserId: newUserId,
            name: user.companyName || `${user.fullName}'s Business`,
            country: user.country,
            currency: ({ NG: 'NGN', MX: 'MXN', CA: 'CAD', GB: 'GBP' } as Record<string, string>)[user.country] ?? 'USD',
            kybStatus: 'unverified',
          },
          update: {
            name: user.companyName || `${user.fullName}'s Business`,
            country: user.country,
          },
        });
      }
    } catch (err) {
      console.warn('[AuthRouter] Non-blocking DB user/business creation notice:', (err as any)?.message || err);
    }
  }

  const capabilities = await resolveCapabilities(newUserId);

  res.status(201).json({
    success: true,
    user,
    capabilities,
    token: issueSessionToken(newUserId),
  });
});

/**
 * POST /api/auth/kyc
 * Completes Tier 1 Personal KYC or Corporate KYB verification.
 * Dispatches to BMONI PATCH /v1/users/{userId}/kyc and POST /kyc/activate,
 * and updates public.users.
 */
authRouter.post('/kyc', requireAuth, async (req, res) => {
  const userId = authedUserId(req);
  const { nationalId, country, accountType, dateOfBirth, address } = req.body;
  let existing = registeredUsers.get(userId);

  if (!existing && isPostgresDb() && userId) {
    try {
      const dbUser = await prisma.user.findFirst({
        where: { id: userId },
      });
      if (dbUser) {
        existing = {
          userId: dbUser.id,
          fullName: dbUser.fullName,
          email: dbUser.email,
          accountType: dbUser.accountType as any,
          country: dbUser.country,
          phone: dbUser.phoneNumber || '',
          companyName: dbUser.companyName || undefined,
          companyRole: dbUser.companyRole || undefined,
          kycStatus: dbUser.kycStatus as any,
          nationalId: dbUser.nationalId || undefined,
        };
        registeredUsers.set(userId, existing);
      }
    } catch (_) {}
  }

  if (!existing && userId) {
    existing = {
      userId,
      fullName: 'FlowPay User',
      email: `user_${userId}@flowpay.finance`,
      accountType: (accountType as any) || 'personal',
      country: country || 'NG',
      phone: '',
      kycStatus: 'pending',
      nationalId: nationalId || undefined,
    };
    registeredUsers.set(userId, existing);
  } else if (existing) {
    existing.kycStatus = 'verified';
    if (nationalId) existing.nationalId = nationalId;
  }

  // Update in database
  if (isPostgresDb() && userId) {
    try {
      await prisma.user.updateMany({
        where: {
          id: userId,
        },
        data: {
          kycStatus: 'pending',
          nationalId: nationalId || undefined,
        },
      });
      await prisma.business.updateMany({
        where: {
          ownerUserId: userId,
        },
        data: {
          kybStatus: 'pending',
          updatedAt: new Date(),
        },
      });
    } catch (err) {
      console.warn('[AuthRouter] Non-blocking DB KYC update notice:', (err as any)?.message || err);
    }
  }

  // TODO(M5): real verification via the payout anchor's SEP-12 KYC endpoint. Until then
  // this only records what the user submitted; no identity data leaves FlowPay.

  res.json({
    success: true,
    // Self-submitted details are not a verification. Identity is verified by the
    // licensed anchor (SEP-12 / SEP-24) when money moves to or from a bank.
    status: 'SUBMITTED',
    kycStatus: 'pending',
    verification: 'anchor',
    verifiedAt: new Date().toISOString(),
  });
});

/**
 * GET /api/auth/capabilities
 * GET /api/auth/users/:newUserId/capabilities
 *
 * Resolves account capabilities for the authenticated user session.
 * Derives whether this newUserId holds a personal smart wallet and
 * whether they are linked as employer/admin to any company/business entity.
 */
authRouter.get('/capabilities', requireAuth, async (req, res) => {
  res.json(await resolveCapabilities(authedUserId(req)));
});

authRouter.get('/users/:id/capabilities', requireAuth, async (req, res, next) => {
  if (req.params.id !== authedUserId(req)) return next(new UnauthorizedError('You can only read your own capabilities.'));
  res.json(await resolveCapabilities(req.params.id));
});

// ── Email verification (required before accepting an employee invite) ──────────

const EMAIL_CODE_TTL_MS = 10 * 60 * 1000;
const emailCodes = new Map<string, { hash: string; expiresAt: number; attempts: number }>();
const hashCode = (userId: string, code: string) => crypto.createHmac('sha256', userId).update(code).digest('hex');

export async function isEmailVerified(userId: string): Promise<boolean> {
  if (registeredUsers.get(userId)?.emailVerified) return true;
  if (isPostgresDb()) {
    const u = await prisma.user.findUnique({ where: { id: userId } });
    return !!u?.emailVerified;
  }
  return false;
}

/** POST /api/auth/email/send — emails a 6-digit code to the signed-in user's address. */
authRouter.post('/email/send', requireAuth, async (req, res, next) => {
  try {
    const userId = authedUserId(req);
    const user = await loadUser(userId);
    if (!user) throw new UnauthorizedError('Account not found.');
    const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
    emailCodes.set(userId, { hash: hashCode(userId, code), expiresAt: Date.now() + EMAIL_CODE_TTL_MS, attempts: 0 });
    if (env.DEV_ECHO_EMAIL_CODES) {
      if (env.NODE_ENV === 'production') throw new InvalidRequestError('DEV_ECHO_EMAIL_CODES is not allowed in production.');
      return res.json({ success: true, data: { sentTo: user.email, devCode: code } });
    }
    const sent = await mailService.sendOtp({ to: user.email, recipientName: user.fullName, code, expiryMinutes: 10, actionDescription: 'verify your email address' });
    if (!sent.success) throw new InvalidRequestError(`We couldn't send the code: ${sent.error ?? 'mail unavailable'}`);
    res.json({ success: true, data: { sentTo: user.email } });
  } catch (err) {
    next(err);
  }
});

/** POST /api/auth/email/verify { code } */
authRouter.post('/email/verify', requireAuth, async (req, res, next) => {
  try {
    const userId = authedUserId(req);
    const entry = emailCodes.get(userId);
    if (!entry || entry.expiresAt < Date.now()) throw new InvalidRequestError('This code expired. Request a new one.');
    if (entry.attempts >= 5) throw new InvalidRequestError('Too many attempts. Request a new code.');
    entry.attempts += 1;
    const ok = crypto.timingSafeEqual(Buffer.from(entry.hash), Buffer.from(hashCode(userId, String(req.body?.code ?? ''))));
    if (!ok) throw new InvalidRequestError('That code is not correct.');
    emailCodes.delete(userId);
    const mem = registeredUsers.get(userId);
    if (mem) mem.emailVerified = true;
    if (isPostgresDb()) await prisma.user.update({ where: { id: userId }, data: { emailVerified: true } });
    res.json({ success: true, data: { emailVerified: true } });
  } catch (err) {
    next(err);
  }
});

/** Testing hook: the code isn't retrievable otherwise. */
export function issueEmailCodeForTests(userId: string): string {
  const code = '123456';
  emailCodes.set(userId, { hash: hashCode(userId, code), expiresAt: Date.now() + EMAIL_CODE_TTL_MS, attempts: 0 });
  return code;
}

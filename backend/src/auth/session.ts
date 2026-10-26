import crypto from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import { env } from '../config/env.js';
import { UnauthorizedError } from '../core/errors.js';

/**
 * Session tokens: HS256 JWTs signed with FLOWPAY_JWT_SECRET.
 *
 * Issued at signup, and at login only after the device proves control of the
 * user's Stellar key (signed challenge). Every user-scoped route takes identity
 * from the verified token — never from headers, query strings or bodies.
 */

export const SESSION_TTL_SECONDS = 12 * 60 * 60;

const b64url = (buf: Buffer | string) => Buffer.from(buf).toString('base64url');

function sign(input: string): string {
  return crypto.createHmac('sha256', env.FLOWPAY_JWT_SECRET).update(input).digest('base64url');
}

export function issueSessionToken(userId: string, now = Math.floor(Date.now() / 1000)): string {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ sub: userId, iat: now, exp: now + SESSION_TTL_SECONDS, iss: 'flowpay' }));
  return `${header}.${payload}.${sign(`${header}.${payload}`)}`;
}

export function verifySessionToken(token: string, now = Math.floor(Date.now() / 1000)): { userId: string; expiresAt: number } {
  const parts = (token ?? '').split('.');
  if (parts.length !== 3) throw new UnauthorizedError('Invalid session token.');
  const [header, payload, signature] = parts;
  const expected = sign(`${header}.${payload}`);
  const a = Buffer.from(signature);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) throw new UnauthorizedError('Invalid session token.');
  let claims: { sub?: string; exp?: number; iss?: string };
  try {
    claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    throw new UnauthorizedError('Invalid session token.');
  }
  if (claims.iss !== 'flowpay' || typeof claims.sub !== 'string' || !claims.sub) throw new UnauthorizedError('Invalid session token.');
  if (typeof claims.exp !== 'number' || claims.exp < now) throw new UnauthorizedError('Your session expired. Please sign in again.');
  return { userId: claims.sub, expiresAt: claims.exp };
}

declare module 'express-serve-static-core' {
  interface Request {
    /** Set by requireAuth from a verified session token. */
    authUserId?: string;
  }
}

/** Rejects requests without a valid `Authorization: Bearer <token>`. */
export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  try {
    const header = req.headers.authorization ?? '';
    if (!header.startsWith('Bearer ')) throw new UnauthorizedError('Sign in required.');
    req.authUserId = verifySessionToken(header.slice(7)).userId;
    next();
  } catch (err) {
    next(err);
  }
}

/** The authenticated user for this request (requireAuth must run first). */
export function authedUserId(req: Request): string {
  if (!req.authUserId) throw new UnauthorizedError('Sign in required.');
  return req.authUserId;
}

import dns from 'node:dns';
import { PrismaClient } from '@prisma/client';
import { env } from '../config/env.js';

if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first');
}

// ---------------------------------------------------------------------------
// Prisma Client — singleton pattern (safe for dev hot-reload via tsx)
// ---------------------------------------------------------------------------

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma: PrismaClient =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      env.NODE_ENV === 'development'
        ? ['query', 'warn', 'error']
        : ['warn', 'error'],
  });

if (env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

// ---------------------------------------------------------------------------
// Database initialisation — run seed if tables are empty
// ---------------------------------------------------------------------------

let isDbConnected = false;

export function isPostgresDb(): boolean {
  return isDbConnected;
}

export function setPostgresConnected(status: boolean): void {
  isDbConnected = status;
}

export async function initDatabase(): Promise<void> {
  const isPostgres =
    env.DATABASE_URL?.startsWith('postgres://') ||
    env.DATABASE_URL?.startsWith('postgresql://');

  if (!isPostgres) {
    isDbConnected = false;
    console.warn(
      `[DB] Notice: DATABASE_URL is not set to a PostgreSQL URI (${env.DATABASE_URL || 'empty'}).\n` +
        `     Set DATABASE_URL=postgresql://user:pass@host:port/dbname in backend/.env.`
    );
    return;
  }

  try {
    await prisma.$connect();
    isDbConnected = true;
    // Prisma handles DDL via migrations; here we only seed demo data
    console.log('[DB] PostgreSQL connected.');
  } catch (err: any) {
    try {
      await new Promise((r) => setTimeout(r, 500));
      await prisma.$connect();
      isDbConnected = true;
      console.log('[DB] PostgreSQL connected on retry.');
    } catch (retryErr: any) {
      isDbConnected = false;
      console.warn('[DB] PostgreSQL unreachable at startup (using in-memory persistence fallback):', retryErr.message || retryErr);
    }
  }
}


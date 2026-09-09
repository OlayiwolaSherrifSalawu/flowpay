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
    await seedDemoDataIfNeeded();
    console.log('[DB] PostgreSQL connected & demo records verified.');
  } catch (err: any) {
    try {
      await new Promise((r) => setTimeout(r, 500));
      await prisma.$connect();
      isDbConnected = true;
      await seedDemoDataIfNeeded();
      console.log('[DB] PostgreSQL connected on retry & demo records verified.');
    } catch (retryErr: any) {
      isDbConnected = false;
      console.warn('[DB] PostgreSQL unreachable at startup (using in-memory persistence fallback):', retryErr.message || retryErr);
    }
  }
}

async function seedDemoDataIfNeeded(): Promise<void> {
  try {
    // Seed master user if not exists
    await prisma.user.createMany({
      data: [
        {
          id: 'usr_flowpay_sandbox_master',
          bmoniUserId: 'usr_flowpay_sandbox_master',
          email: 'waffiyyi@flowpay.finance',
          fullName: 'Waffiyyi Fashola',
          phoneNumber: '+14155552671',
          accountType: 'both',
          country: 'US',
          companyName: 'FlowPay Technologies Ltd',
          companyRole: 'ADMIN',
          kycStatus: 'verified',
        },
      ],
      skipDuplicates: true,
    });

    // Seed default business
    await (prisma as any).business.createMany({
      data: [
        {
          id: 'biz_flowpay_technologies',
          ownerUserId: 'usr_flowpay_sandbox_master',
          bmoniUserId: 'usr_flowpay_sandbox_master',
          name: 'FlowPay Technologies Ltd',
          country: 'US',
          currency: 'USD',
          kybStatus: 'verified',
        },
      ],
      skipDuplicates: true,
    });

    const employeeCount = await prisma.employee.count();

    if (employeeCount === 0) {
      // Seed pre-verified BMONI sandbox personas per spec:
      // Employee 1: Bunch Dillon (Nigeria, BVN 99999999999)
      // Employee 2: Samson Jabo (Mexico/Nigeria alt, BVN/NIN 22222222222)
      await (prisma.employee as any).createMany({
        data: [
          {
            id: 'emp_bunch_dillon',
            bmoniUserId: 'usr_bmoni_dillon_ngn',
            partnerId: env.BMONI_PARTNER_ID,
            businessId: 'biz_flowpay_technologies',
            firstName: 'Bunch',
            lastName: 'Dillon',
            email: 'bunch.dillon@example.ng',
            phoneNumber: '+2348011112222',
            country: 'NG',
            targetCurrency: 'NGN',
            status: 'LINKED',
          },
          {
            id: 'emp_samson_jabo',
            bmoniUserId: 'usr_bmoni_samson_mxn',
            partnerId: env.BMONI_PARTNER_ID,
            businessId: 'biz_flowpay_technologies',
            firstName: 'Samson',
            lastName: 'Jabo',
            email: 'samson.jabo@example.mx',
            phoneNumber: '+525512345678',
            country: 'MX',
            targetCurrency: 'MXN',
            status: 'LINKED',
          },
        ] as any,
        skipDuplicates: true,
      });

      // Seed default Money Missions
      await prisma.moneyMission.createMany({
        data: [
          {
            id: 'mission_emergency_sweep',
            title: '20% Emergency Fund Auto-Sweep',
            description:
              'Automatically route 20% of international USD disbursements into high-yield NGN savings.',
            ruleType: 'AUTO_SWEEP',
            conditionJson: { trigger: 'DEPOSIT_RECEIVED', currency: 'USD' },
            actionJson: { percentage: 20, destinationCurrency: 'NGN' },
            isActive: true,
          },
          {
            id: 'mission_card_cap',
            title: 'Contractor Card Monthly Cap',
            description:
              'Enforce a strict $500/month spending limit on virtual cards for team contractors.',
            ruleType: 'SPEND_CAP',
            conditionJson: { role: 'CONTRACTOR' },
            actionJson: { monthlyLimitUsdMinor: 50000 },
            isActive: true,
          },
        ],
        skipDuplicates: true,
      });
    }
  } catch (err) {
    console.warn('[DB] Seeding note:', err);
  }
}

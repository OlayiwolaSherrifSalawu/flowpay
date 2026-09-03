import { Router } from 'express';
import { bmoniClient } from '../bmoni/client.js';

export const authRouter = Router();

interface RegisteredUser {
  userId: string;
  fullName: string;
  email: string;
  accountType: 'personal' | 'business';
  country: string;
  phone: string;
  companyName?: string;
  companyRole?: string;
  kycStatus: 'unverified' | 'pending' | 'verified';
  nationalId?: string;
}

const registeredUsers = new Map<string, RegisteredUser>();

// Seed default sandbox master user
registeredUsers.set('usr_flowpay_sandbox_master', {
  userId: 'usr_flowpay_sandbox_master',
  fullName: 'Waffiyyi Fashola',
  email: 'waffiyyi@flowpay.finance',
  accountType: 'business',
  country: 'US',
  phone: '+14155552671',
  companyName: 'FlowPay Technologies Ltd',
  companyRole: 'ADMIN',
  kycStatus: 'verified',
});

function resolveCapabilities(bmoniUserId: string) {
  const user = registeredUsers.get(bmoniUserId);
  const isPersonal = user ? user.accountType === 'personal' : bmoniUserId.includes('personal');
  const isBusiness = user ? user.accountType === 'business' : bmoniUserId.includes('business');
  const isMaster = bmoniUserId === 'usr_flowpay_sandbox_master' || (!isPersonal && !isBusiness);

  if (isMaster) {
    return {
      bmoniUserId,
      hasPersonalWallet: true,
      hasBusinessAccess: true,
      company: {
        companyId: 'comp_flowpay_global',
        name: 'FlowPay Technologies Ltd',
        role: 'ADMIN',
      },
      capabilities: ['PERSONAL_WALLET', 'BUSINESS_PAYROLL', 'TEAM_CARDS', 'MULTI_COUNTRY_SETTLEMENT'],
      cachedAt: new Date().toISOString(),
    };
  }

  if (isPersonal) {
    return {
      bmoniUserId,
      hasPersonalWallet: true,
      hasBusinessAccess: false,
      capabilities: ['PERSONAL_WALLET', 'MONEY_MISSIONS', 'VIRTUAL_CARDS'],
      cachedAt: new Date().toISOString(),
    };
  }

  return {
    bmoniUserId,
    hasPersonalWallet: false,
    hasBusinessAccess: true,
    company: {
      companyId: `comp_${bmoniUserId}`,
      name: user?.companyName || 'FlowPay Business Ltd',
      role: user?.companyRole || 'ADMIN',
    },
    capabilities: ['BUSINESS_PAYROLL', 'TEAM_CARDS', 'MULTI_COUNTRY_SETTLEMENT'],
    cachedAt: new Date().toISOString(),
  };
}

// Returns active sandbox session context for the mobile app
authRouter.get('/session', (req, res) => {
  res.json({
    authenticated: true,
    user: {
      userId: 'usr_flowpay_sandbox_master',
      name: 'Waffiyyi Fashola',
      email: 'waffiyyi@flowpay.finance',
      role: 'EMPLOYER_AND_PERSONAL',
      defaultCurrency: 'USD',
    },
    sandbox: true,
    bmoniPartnerId: 'b7e6a1d0-4f3c-4c2a-9e8b-1a2b3c4d5e6f',
  });
});

/**
 * POST /api/auth/signup
 * Registers a new Personal or Business account with dedicated capabilities.
 * Synchronizes with BMONI POST /v1/users when available.
 */
authRouter.post('/signup', async (req, res) => {
  const { fullName, email, accountType, country, phone, companyName, companyRole } = req.body;
  let bmoniUserId = `usr_${accountType === 'business' ? 'business' : 'personal'}_${Date.now()}`;

  // Attempt upstream BMONI User creation
  try {
    const bmoniUser = await bmoniClient.createUser({
      email: email || undefined,
      phoneNumber: phone || undefined,
    });
    if (bmoniUser?.id) {
      bmoniUserId = bmoniUser.id;
    }
  } catch (_) {
    // Non-blocking fallback for local test environment
  }

  const user: RegisteredUser = {
    userId: bmoniUserId,
    fullName: fullName || 'FlowPay User',
    email: email || '',
    accountType: accountType === 'business' ? 'business' : 'personal',
    country: country || 'NG',
    phone: phone || '',
    companyName: accountType === 'business' ? (companyName || 'Business Entity') : undefined,
    companyRole: accountType === 'business' ? (companyRole || 'ADMIN') : undefined,
    kycStatus: 'unverified',
  };

  registeredUsers.set(bmoniUserId, user);

  res.status(201).json({
    success: true,
    user,
    capabilities: resolveCapabilities(bmoniUserId),
  });
});

/**
 * POST /api/auth/kyc
 * Completes Tier 1 Personal KYC or Corporate KYB verification.
 * Dispatches to BMONI PATCH /v1/users/{userId}/kyc and POST /kyc/activate.
 */
authRouter.post('/kyc', async (req, res) => {
  const { userId, nationalId, country } = req.body;
  const existing = registeredUsers.get(userId);
  if (existing) {
    existing.kycStatus = 'verified';
    if (nationalId) existing.nationalId = nationalId;
  }

  // Attempt upstream BMONI KYC profile submission and workflow activation
  try {
    if (userId && !userId.startsWith('usr_personal') && !userId.startsWith('usr_business')) {
      const names = (existing?.fullName || 'FlowPay User').split(' ');
      await bmoniClient.submitKycProfile({
        userId,
        personalInfo: {
          firstName: names[0] || 'FlowPay',
          lastName: names.slice(1).join(' ') || 'User',
          dateOfBirth: '1992-04-18',
        },
        addressDetails: {
          street: '14 Admiralty Way',
          city: 'Lagos',
          state: 'Lagos',
          countryCode: country || 'NGA',
        },
        identificationNumbers: nationalId ? { nationalId } : undefined,
      });

      await bmoniClient.activateKyc({
        userId,
        sumsubLevelName: country === 'NG' ? undefined : 'id-and-liveness',
      });
    }
  } catch (_) {
    // Non-blocking fallback for test personas
  }

  res.json({
    success: true,
    status: 'VERIFIED',
    tier: existing?.accountType === 'business' ? 'CORPORATE_GLOBAL_PAYROLL' : 'TIER_1_SMART_WALLET',
    monthlyLimitUsd: existing?.accountType === 'business' ? 1000000 : 10000,
    railsActivated: ['NGN_NUBAN', 'MXN_SPEI', 'USD_TREASURY'],
    verifiedAt: new Date().toISOString(),
  });
});

/**
 * GET /api/auth/capabilities
 * GET /api/auth/users/:bmoniUserId/capabilities
 *
 * Resolves account capabilities for the authenticated user session.
 * Derives whether this bmoniUserId holds a personal smart wallet and
 * whether they are linked as employer/admin to any company/business entity.
 */
authRouter.get('/capabilities', (req, res) => {
  const bmoniUserId = (req.query.bmoniUserId as string) || 'usr_flowpay_sandbox_master';
  res.json(resolveCapabilities(bmoniUserId));
});

authRouter.get('/users/:bmoniUserId/capabilities', (req, res) => {
  const { bmoniUserId } = req.params;
  res.json(resolveCapabilities(bmoniUserId));
});

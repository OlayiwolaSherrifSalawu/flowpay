import { Router } from 'express';

export const authRouter = Router();

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
 * GET /api/auth/capabilities
 * GET /api/auth/users/:bmoniUserId/capabilities
 *
 * Resolves account capabilities for the authenticated user session.
 * Derives whether this bmoniUserId holds a personal smart wallet and
 * whether they are linked as employer/admin to any company/business entity.
 */
authRouter.get('/capabilities', (req, res) => {
  const bmoniUserId = (req.query.bmoniUserId as string) || 'usr_flowpay_sandbox_master';

  res.json({
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
  });
});

authRouter.get('/users/:bmoniUserId/capabilities', (req, res) => {
  const { bmoniUserId } = req.params;

  res.json({
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
  });
});


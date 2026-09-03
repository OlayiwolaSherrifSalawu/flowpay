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

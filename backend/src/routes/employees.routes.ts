import { Router } from 'express';
import { EmployeeService } from '../modules/employees/service.js';
import { EmployeeOnboardingService } from '../modules/employees/onboarding.service.js';

export const employeesRouter = Router();

// GET /api/employees?status=READY
employeesRouter.get('/', async (req, res, next) => {
  try {
    const status = req.query.status as string | undefined;
    const list = await EmployeeService.listEmployees(status);
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/status/:status
employeesRouter.get('/status/:status', async (req, res, next) => {
  try {
    const list = await EmployeeService.listEmployees(req.params.status);
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id
employeesRouter.get('/:id', async (req, res, next) => {
  try {
    const employee = await EmployeeService.getEmployeeById(req.params.id);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }
    res.json({ success: true, data: employee });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees - Primary employee creation endpoint with server-side validation
employeesRouter.post('/', async (req, res, next) => {
  try {
    const { firstName, lastName, email, phoneNumber, country, targetCurrency, payrollAmountMinor, payrollCurrency } =
      req.body;

    // Handle either payrollAmountMinor directly or payrollAmount in major
    let amountMinor = payrollAmountMinor;
    if (amountMinor === undefined && req.body.payrollAmount !== undefined) {
      amountMinor = Number.isInteger(req.body.payrollAmount)
        ? req.body.payrollAmount
        : Math.round(Number(req.body.payrollAmount) * 100);
    }
    if (amountMinor === undefined && req.body.salary !== undefined) {
      amountMinor = Math.round(Number(req.body.salary) * 100);
    }

    const result = await EmployeeService.createEmployee({
      firstName,
      lastName,
      email,
      phoneNumber,
      country,
      targetCurrency,
      payrollAmountMinor: amountMinor ?? 0,
      payrollCurrency,
    });

    res.status(201).json({
      success: true,
      message: 'Employee created successfully with BMONI on-chain identity',
      data: result,
    });
  } catch (err: any) {
    if (err.statusCode === 400 || err.errors) {
      return res.status(400).json({
        success: false,
        message: err.message,
        errors: err.errors || [err.message],
      });
    }
    next(err);
  }
});

// POST /api/employees/invite - Backward compatibility alias
employeesRouter.post('/invite', async (req, res, next) => {
  try {
    const result = await EmployeeService.inviteEmployee(req.body);
    res.json({ success: true, data: result });
  } catch (err: any) {
    if (err.statusCode === 400 || err.errors) {
      return res.status(400).json({
        success: false,
        message: err.message,
        errors: err.errors,
      });
    }
    next(err);
  }
});

// PATCH /api/employees/:id/status - Update lifecycle stage
employeesRouter.patch('/:id/status', async (req, res, next) => {
  try {
    const { status, failedStage } = req.body;
    if (!status) {
      return res.status(400).json({ success: false, message: 'status is required' });
    }

    const updated = await EmployeeService.updateEmployeeStatus(req.params.id, status, failedStage);
    if (!updated) {
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }

    res.json({ success: true, data: updated });
  } catch (err) {
    next(err);
  }
});

// =========================================================================
// BMONI MULTI-STAGE ONBOARDING ENDPOINTS (Stages 2, 3, 4)
// =========================================================================

// POST /api/employees/:id/onboarding/challenge - Stage 2: Request Owner Proof Challenge
employeesRouter.post('/:id/onboarding/challenge', async (req, res, next) => {
  try {
    const { userOwnerAddress } = req.body;
    const challenge = await EmployeeOnboardingService.requestOwnerChallenge(req.params.id, userOwnerAddress);
    res.json({ success: true, data: challenge });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/wallet - Stage 2: Deploy Managed Smart Wallet
employeesRouter.post('/:id/onboarding/wallet', async (req, res, next) => {
  try {
    const { userOwnerAddress, ownerProofChallengeId, ownerProofSignature } = req.body;
    const result = await EmployeeOnboardingService.provisionSmartWallet(req.params.id, {
      userOwnerAddress,
      ownerProofChallengeId,
      ownerProofSignature,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id/onboarding/kyc/options - Stage 3: Get KYC options
employeesRouter.get('/:id/onboarding/kyc/options', async (req, res, next) => {
  try {
    const options = await EmployeeOnboardingService.getKycOptions(req.params.id);
    res.json({ success: true, data: options });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/kyc/submit - Stage 3: Submit Country-Specific KYC
employeesRouter.post('/:id/onboarding/kyc/submit', async (req, res, next) => {
  try {
    const result = await EmployeeOnboardingService.submitCountryKyc(req.params.id, req.body);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id/onboarding/kyc/readiness - Stage 3: Check readiness gate
employeesRouter.get('/:id/onboarding/kyc/readiness', async (req, res, next) => {
  try {
    const readiness = await EmployeeOnboardingService.checkKycReadiness(req.params.id);
    res.json({ success: true, data: readiness });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/kyc/activate - Stage 3: Activate KYC
employeesRouter.post('/:id/onboarding/kyc/activate', async (req, res, next) => {
  try {
    const result = await EmployeeOnboardingService.activateKyc(req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id/onboarding/mx/agreements - Stage 4 (Mexico): Fetch Etherfuse agreements
employeesRouter.get('/:id/onboarding/mx/agreements', async (req, res, next) => {
  try {
    const agreements = await EmployeeOnboardingService.getMexicoAgreements(req.params.id);
    res.json({ success: true, data: agreements });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/activate-rail - Stage 4: Activate Country Rail
employeesRouter.post('/:id/onboarding/activate-rail', async (req, res, next) => {
  try {
    const result = await EmployeeOnboardingService.activateRail(req.params.id, req.body);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id/onboarding/status - Aggregate status across stages 2/3/4
employeesRouter.get('/:id/onboarding/status', async (req, res, next) => {
  try {
    const status = await EmployeeOnboardingService.getOnboardingStatus(req.params.id);
    res.json({ success: true, data: status });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/retry - Retry failed or pending stage
employeesRouter.post('/:id/onboarding/retry', async (req, res, next) => {
  try {
    const status = await EmployeeOnboardingService.retryStage(req.params.id);
    res.json({ success: true, data: status });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/onboarding/simulate-complete - Sandbox webhook completion simulation
employeesRouter.post('/:id/onboarding/simulate-complete', async (req, res, next) => {
  try {
    const status = await EmployeeOnboardingService.simulateOnboardingCompleted(req.params.id);
    res.json({ success: true, data: status });
  } catch (err) {
    next(err);
  }
});


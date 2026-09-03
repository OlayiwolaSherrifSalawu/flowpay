import { Router } from 'express';
import { EmployeeService } from '../modules/employees/service.js';

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

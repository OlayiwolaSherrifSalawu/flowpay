import { Router } from 'express';
import { EmployeeService } from '../modules/employees/service.js';

export const employeesRouter = Router();

// GET /api/employees
employeesRouter.get('/', (req, res, next) => {
  try {
    const list = EmployeeService.listEmployees();
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id
employeesRouter.get('/:id', (req, res, next) => {
  try {
    const employee = EmployeeService.getEmployeeById(req.params.id);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }
    res.json({ success: true, data: employee });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/invite
employeesRouter.post('/invite', async (req, res, next) => {
  try {
    const result = await EmployeeService.inviteEmployee(req.body);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

import { authedUserId, requireAuth } from '../auth/session.js';
import { Router, type Request } from 'express';
import { FlowPayError, InvalidRequestError } from '../core/errors.js';
import { paginateArray, parsePaginationParams } from '../core/pagination.js';
import { EmployeeService, publicEmployee } from '../modules/employees/service.js';

export const employeesRouter = Router();

// Everything requires a signed-in user except the public invite landing page.
employeesRouter.use((req, res, next) => (req.method === 'GET' && req.path.startsWith('/invite/') ? next() : requireAuth(req, res, next)));

// Identity comes only from the verified session token (see auth/session.ts).
const requestUserId = (req: Request) => authedUserId(req);

function escapeHtml(value: unknown): string {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

function parseAmountMinor(body: any): number {
  if (body.payrollAmountMinor !== undefined) return Number.parseInt(String(body.payrollAmountMinor), 10);
  if (body.payrollAmount !== undefined) return Math.round(Number(body.payrollAmount) * 100);
  if (body.salary !== undefined) return Math.round(Number(body.salary) * 100);
  return 0;
}

const withInvite = (e: Parameters<typeof publicEmployee>[0]) => ({ ...publicEmployee(e), inviteUrl: EmployeeService.shareableInviteUrl(e.id) });

// GET /api/employees — this employer's team only.
employeesRouter.get('/', async (req, res, next) => {
  try {
    let list = await EmployeeService.listEmployees(requestUserId(req), req.query.status as string | undefined);
    const country = req.query.country as string | undefined;
    if (country && country !== 'ALL') list = list.filter((e) => e.country === country.toUpperCase());
    const search = (req.query.search as string | undefined)?.toLowerCase();
    if (search) list = list.filter((e) => `${e.firstName} ${e.lastName} ${e.email} ${e.country}`.toLowerCase().includes(search));
    const data = list.map(withInvite);
    if (req.query.page !== undefined || req.query.limit !== undefined) {
      const { page, limit } = parsePaginationParams(req.query, 10);
      return res.json({ success: true, data: paginateArray(data, page, limit) });
    }
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees — add an employee and create their invite link.
employeesRouter.post('/', async (req, res, next) => {
  try {
    const result = await EmployeeService.createEmployee(requestUserId(req), { ...req.body, payrollAmountMinor: parseAmountMinor(req.body) });
    res.status(201).json({
      success: true,
      message: result.inviteEmailSent ? 'Employee invited by email.' : 'Employee added. Share the invite link with them.',
      data: { employee: withInvite(result.employee), inviteUrl: result.inviteUrl, inviteToken: result.inviteToken, inviteEmailSent: result.inviteEmailSent },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/invite — alias kept for older clients.
employeesRouter.post('/invite', async (req, res, next) => {
  try {
    const result = await EmployeeService.createEmployee(requestUserId(req), { ...req.body, payrollAmountMinor: parseAmountMinor(req.body) });
    res.status(201).json({ success: true, data: { employee: withInvite(result.employee), inviteUrl: result.inviteUrl, inviteToken: result.inviteToken } });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/invite/:token — public; JSON for the app, HTML landing page for browsers.
employeesRouter.get('/invite/:token', async (req, res, next) => {
  const wantsHtml = req.headers.accept?.includes('text/html');
  try {
    const invite = await EmployeeService.getInviteDetails(req.params.token);
    if (!wantsHtml) return res.json({ success: true, data: invite });
    const salary = (invite.payrollAmountMinor / 100).toLocaleString('en-US', { style: 'currency', currency: invite.targetCurrency });
    return res.send(`<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FlowPay invitation</title>
<style>
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0b0f19;color:#f3f4f6;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:16px;box-sizing:border-box}
.card{background:#111827;border:1px solid #1f2937;border-radius:16px;max-width:480px;width:100%;padding:28px}
h1{font-size:22px;margin:0 0 8px}p{color:#9ca3af;font-size:14px;line-height:20px}
.row{display:flex;justify-content:space-between;font-size:14px;margin:8px 0}.label{color:#9ca3af}
.btn{display:block;text-align:center;background:#fdda24;color:#0b0f19;text-decoration:none;font-weight:700;padding:14px;border-radius:10px;margin-top:20px}
</style></head><body><div class="card">
<h1>${escapeHtml(invite.companyName)} invited you to FlowPay</h1>
<p>Get paid on the Stellar network into a wallet that only you control.</p>
<div class="row"><span class="label">Name</span><span>${escapeHtml(invite.firstName)} ${escapeHtml(invite.lastName)}</span></div>
<div class="row"><span class="label">Paid in</span><span>${escapeHtml(invite.targetCurrency)}</span></div>
<div class="row"><span class="label">Salary</span><span>${escapeHtml(salary)}</span></div>
<a class="btn" href="flowpay://invite/${escapeHtml(req.params.token)}">Open in FlowPay</a>
<p style="font-size:12px">Sign up with ${escapeHtml(invite.email)}, create your wallet, then accept the invitation.</p>
</div></body></html>`);
  } catch (err) {
    if (wantsHtml && err instanceof FlowPayError) {
      return res.status(err.statusCode).send(`<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Invitation unavailable</title></head>
<body style="font-family:sans-serif;background:#0b0f19;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px">
<div style="background:#111827;padding:28px;border-radius:16px;max-width:400px"><h2>Invitation unavailable</h2><p style="color:#9ca3af">${escapeHtml(err.message)}</p></div></body></html>`);
    }
    next(err);
  }
});

// POST /api/employees/invite/:token/accept — the signed-in employee accepts with their proven wallet.
employeesRouter.post('/invite/:token/accept', async (req, res, next) => {
  try {
    const employee = await EmployeeService.acceptInvite({ token: req.params.token, requestingUserId: requestUserId(req) });
    res.json({ success: true, message: 'You are on the payroll.', data: publicEmployee(employee) });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/link-wallet { inviteToken } — alias for older clients.
employeesRouter.post('/link-wallet', async (req, res, next) => {
  try {
    const token = req.body?.inviteToken;
    if (typeof token !== 'string') throw new InvalidRequestError('inviteToken is required');
    const employee = await EmployeeService.acceptInvite({ token, requestingUserId: requestUserId(req) });
    res.json({ success: true, data: publicEmployee(employee) });
  } catch (err) {
    next(err);
  }
});

// GET /api/employees/:id
employeesRouter.get('/:id', async (req, res, next) => {
  try {
    res.json({ success: true, data: withInvite(await EmployeeService.getEmployee(requestUserId(req), req.params.id)) });
  } catch (err) {
    next(err);
  }
});

// POST /api/employees/:id/resend-invite — new link, old one stops working.
employeesRouter.post('/:id/resend-invite', async (req, res, next) => {
  try {
    const r = await EmployeeService.resendInvite(requestUserId(req), req.params.id);
    res.json({ success: true, data: { employee: withInvite(r.employee), inviteUrl: r.inviteUrl, inviteToken: r.inviteToken } });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/employees/:id { status?, payrollAmountMinor? }
employeesRouter.patch('/:id', async (req, res, next) => {
  try {
    const e = await EmployeeService.updateEmployee(requestUserId(req), req.params.id, req.body ?? {});
    res.json({ success: true, data: withInvite(e) });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/employees/:id/status — alias.
employeesRouter.patch('/:id/status', async (req, res, next) => {
  try {
    const e = await EmployeeService.updateEmployee(requestUserId(req), req.params.id, { status: req.body?.status });
    res.json({ success: true, data: withInvite(e) });
  } catch (err) {
    next(err);
  }
});

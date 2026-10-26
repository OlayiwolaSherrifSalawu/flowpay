import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import { env } from './config/env.js';
import { FlowPayError } from './core/errors.js';
import { initDatabase, isPostgresDb, prisma } from './db/index.js';
import { activityRouter } from './routes/activity.routes.js';
import { aiRouter } from './routes/ai.routes.js';
import { authRouter } from './routes/auth.routes.js';
import { employeesRouter } from './routes/employees.routes.js';
import { missionsRouter } from './routes/missions.routes.js';
import { payrollRouter } from './routes/payroll.routes.js';
import { transfersRouter } from './routes/transfers.routes.js';
import { walletsRouter } from './routes/wallets.routes.js';
import { mailRouter } from './routes/mail.routes.js';
import { mailService } from './modules/mail/service.js';
import { banksRouter } from './routes/banks.routes.js';
import { stellarRouter } from './routes/stellar.routes.js';
import { paymentsRouter } from './routes/payments.routes.js';
import { getNetworkConfig } from './stellar/config.js';
import { StellarHorizon } from './stellar/horizon.js';

const app = express();

// 1. CORS
app.use(cors());

// 2. Global JSON parser
app.use(express.json());

// 4. Health check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'flowpay-backend',
    version: '1.0.0',
    dbConnected: isPostgresDb(),
    stellarNetwork: getNetworkConfig().network,
    timestamp: new Date().toISOString(),
  });
});

// Stellar connectivity probe: Horizon reachable and fees readable.
app.get('/api/health/stellar', async (_req: Request, res: Response) => {
  const cfg = getNetworkConfig();
  try {
    const baseFee = await new StellarHorizon().baseFee();
    res.json({ status: 'ok', network: cfg.network, horizonUrl: cfg.horizonUrl, baseFeeStroops: baseFee });
  } catch (err: any) {
    res.status(503).json({ status: 'error', network: cfg.network, horizonUrl: cfg.horizonUrl, detail: err?.message });
  }
});

app.get('/api/health/db', async (req: Request, res: Response) => {
  const connected = isPostgresDb();
  if (!connected) {
    return res.status(503).json({
      status: 'disconnected',
      isPostgresDb: false,
      message: 'PostgreSQL database is not connected. Operations are falling back to in-memory.',
    });
  }
  try {
    await prisma.$queryRaw`SELECT 1`;
    const employeeCount = await prisma.employee.count();
    return res.json({
      status: 'connected',
      isPostgresDb: true,
      tablesVerified: true,
      employeeCount,
    });
  } catch (err: any) {
    return res.status(500).json({
      status: 'error',
      isPostgresDb: true,
      error: err.message || err,
    });
  }
});

// 5. Register API routes
app.use('/api/auth', authRouter);
app.use('/api/wallets', walletsRouter);
app.use('/api/transfers', transfersRouter);
app.use('/api/employees', employeesRouter);
app.use('/api/payroll', payrollRouter);
app.use('/api/missions', missionsRouter);
app.use('/api/ai', aiRouter);
app.use('/api/activity', activityRouter);
app.use('/api/mail', mailRouter);
app.use('/api/banks', banksRouter);
app.use('/api/stellar', stellarRouter);
app.use('/api/payments', paymentsRouter);

// Top-level invite link route (for web previews and deep links)
app.use('/invite', (req: Request, res: Response) => {
  res.redirect(`/api/employees/invite${req.url}`);
});

// 6. Global Error Handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof FlowPayError) {
    return res.status(err.statusCode).json({
      success: false,
      statusCode: err.statusCode,
      code: err.code,
      message: err.message,
      details: err.details,
    });
  }

  console.error('[Unhandled Error]', err);
  return res.status(500).json({
    success: false,
    statusCode: 500,
    code: 'INTERNAL_SERVER_ERROR',
    message: 'An unexpected internal error occurred.',
  });
});

// Initialize database and start server
initDatabase();

if (process.env.NODE_ENV !== 'test') {
  app.listen(env.PORT, () => {
    console.log(`=============================================`);
    console.log(` FlowPay Backend Running on http://localhost:${env.PORT}`);
    console.log(` Stellar: ${getNetworkConfig().network} (${getNetworkConfig().horizonUrl})`);
    console.log(` Mail Relay: ${env.SMTP_HOST}:${env.SMTP_PORT} (${env.SMTP_USER})`);
    console.log(`=============================================`);

    // Verify SMTP connection in background
    mailService.verifyConnection().catch((err: any) => {
      console.warn('[Server] Initial SMTP connection verification warning:', err?.message || err);
    });

  });
}

export default app;

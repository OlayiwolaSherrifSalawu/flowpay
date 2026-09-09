import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import { env } from './config/env.js';
import { bmoniClient } from './bmoni/client.js';
import { FlowPayError, sanitizeBmoniError } from './core/errors.js';
import { initDatabase, isPostgresDb, prisma } from './db/index.js';
import { activityRouter } from './routes/activity.routes.js';
import { aiRouter } from './routes/ai.routes.js';
import { authRouter } from './routes/auth.routes.js';
import { cardsRouter } from './routes/cards.routes.js';
import { employeesRouter } from './routes/employees.routes.js';
import { missionsRouter } from './routes/missions.routes.js';
import { payrollRouter } from './routes/payroll.routes.js';
import { transfersRouter } from './routes/transfers.routes.js';
import { walletsRouter } from './routes/wallets.routes.js';
import { webhookRouter } from './routes/webhook.routes.js';
import { webhookConfigRouter } from './routes/webhook-config.routes.js';
import { mailRouter } from './routes/mail.routes.js';
import { mailService } from './modules/mail/service.js';

const app = express();

// 1. CORS
app.use(cors());

// 2. Webhook route with raw body buffer parsing
// MUST mount before global express.json()
app.use('/webhooks', webhookRouter);

// 3. Global JSON parser for standard API routes
app.use(express.json());

// 4. Health check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'flowpay-backend',
    version: '1.0.0',
    dbConnected: isPostgresDb(),
    bmoniOrigin: env.BMONI_BASE_URL,
    timestamp: new Date().toISOString(),
  });
});

// BMONI connectivity + auth probe. Hit this after deploy to confirm the API
// key actually works BEFORE trying to add employees. A 200 with
// authenticated:true means user creation will work; authenticated:false means
// every employee will fail at BMONI_USER_CREATION until BMONI_API_KEY is fixed.
app.get('/api/health/bmoni', async (req: Request, res: Response) => {
  const result = await bmoniClient.checkConnectivity();
  res.status(result.ok ? 200 : 503).json({
    status: result.ok ? 'ok' : 'error',
    ...result,
  });
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
app.use('/api/cards', cardsRouter);
app.use('/api/employees', employeesRouter);
app.use('/api/payroll', payrollRouter);
app.use('/api/missions', missionsRouter);
app.use('/api/ai', aiRouter);
app.use('/api/activity', activityRouter);
app.use('/api/webhooks', webhookConfigRouter);
app.use('/api/mail', mailRouter);

// Top-level invite link route (for web previews and deep links)
app.use('/invite', (req: Request, res: Response) => {
  res.redirect(`/api/employees/invite${req.url}`);
});

// 6. Global Error Handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  const safeErr = sanitizeBmoniError(err);
  if (safeErr instanceof FlowPayError) {
    return res.status(safeErr.statusCode).json({
      success: false,
      statusCode: safeErr.statusCode,
      code: safeErr.code,
      message: safeErr.message,
      details: safeErr.details,
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
    console.log(` BMONI Infrastructure: ${env.BMONI_BASE_URL}`);
    console.log(` Webhook URL: http://localhost:${env.PORT}/webhooks/bmoni`);
    console.log(` Mail Relay: ${env.SMTP_HOST}:${env.SMTP_PORT} (${env.SMTP_USER})`);
    console.log(`=============================================`);

    // Verify SMTP connection in background
    mailService.verifyConnection().catch((err) => {
      console.warn('[Server] Initial SMTP connection verification warning:', err.message || err);
    });

    // Verify BMONI API key at startup so a misconfigured key is loud and
    // obvious in the deploy logs instead of silently failing every employee.
    if (bmoniClient.isApiKeyLikelyMisconfigured()) {
      console.warn(
        '[Server] ⚠️  BMONI_API_KEY looks like a placeholder or is not a pk_ key. ' +
          'Employee creation (POST /v1/users) will fail with 401 until this is set correctly.'
      );
    }
    bmoniClient
      .checkConnectivity()
      .then((r) => {
        if (r.authenticated) {
          console.log(`[Server] ✅ BMONI reachable & authenticated at ${r.baseUrl}`);
        } else {
          console.warn(`[Server] ⚠️  BMONI auth check failed: ${r.detail}`);
        }
      })
      .catch((err) => {
        console.warn('[Server] BMONI connectivity check warning:', err.message || err);
      });
  });
}

export default app;

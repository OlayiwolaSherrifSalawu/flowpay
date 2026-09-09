import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.string().default('4000').transform((val) => parseInt(val, 10)),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  DATABASE_URL: z.string().default('postgresql://postgres:flowpay@localhost:5432/flowpay'),
  FLOWPAY_JWT_SECRET: z.string().default('flowpay_development_secret_change_in_production_min32chars'),
  APP_URL: z.string().default('https://app.flowpay.finance'),
  // BMONI Configuration
  // Sandbox (development) base URL is https://embedded-dev.bmoni.com.
  // Production is https://embedded.bmoni.com — override BMONI_BASE_URL in prod.
  BMONI_BASE_URL: z.string().default('https://embedded-dev.bmoni.com').transform((url) => {
    // Enforce origin-only: strip any trailing slash or /v1 to prevent /v1/v1/ 404s
    return url.replace(/\/v1\/?$/, '').replace(/\/$/, '');
  }),
  // Documented shared SANDBOX key for the embedded-dev base URL (see BMONI
  // api-quickstart). This is a real, working sandbox key — used as the default
  // so the app works out of the box in the demo. For production you MUST set
  // BMONI_API_KEY to your own key in the environment. A missing/placeholder
  // key is what causes every POST /v1/users to fail with 401 Unauthorized and
  // every employee to land as status=FAILED / failed_stage=BMONI_USER_CREATION.
  BMONI_API_KEY: z
    .string()
    .default('pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4'),
  BMONI_WEBHOOK_SECRET: z.string().default('87f88be98b96faf6d6ece5b26bf4a9fe20739ae9634fb7b530a24aac4f71ed32'),
  BMONI_PARTNER_ID: z.string().default('b7e6a1d0-4f3c-4c2a-9e8b-1a2b3c4d5e6f'),
  GEMINI_API_KEY: z.string().optional(),
  // Mail Configuration (Gmail SMTP)
  SMTP_HOST: z.string().default('smtp.gmail.com'),
  SMTP_PORT: z.string().default('587').transform((val) => parseInt(val, 10)),
  SMTP_SECURE: z.string().default('false').transform((val) => val === 'true'),
  SMTP_USER: z.string().default('fwaffiyyi@gmail.com'),
  SMTP_PASS: z.string().default(''),
  MAIL_FROM_NAME: z.string().default('FlowPay'),
  MAIL_FROM_ADDRESS: z.string().default('fwaffiyyi@gmail.com'),
  // Paystack Configuration
  PAYSTACK_SECRET_KEY: z.string().optional(),
  PAYSTACK_BASE_URL: z.string().default('https://api.paystack.co').transform((url) => {
    return url.replace(/\/$/, '');
  }),
});

export const env = envSchema.parse(process.env);

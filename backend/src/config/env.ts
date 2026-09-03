import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.string().default('4000').transform((val) => parseInt(val, 10)),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  DATABASE_URL: z.string().default('./flowpay.db'),
  FLOWPAY_JWT_SECRET: z.string().default('flowpay_development_secret_change_in_production_min32chars'),
  // BMONI Configuration
  BMONI_BASE_URL: z.string().default('https://embedded-dev.bmoni.com').transform((url) => {
    // Enforce origin-only: strip any trailing slash or /v1 to prevent /v1/v1/ 404s
    return url.replace(/\/v1\/?$/, '').replace(/\/$/, '');
  }),
  BMONI_API_KEY: z.string().default('sandbox_bmoni_api_key_placeholder'),
  BMONI_WEBHOOK_SECRET: z.string().default('87f88be98b96faf6d6ece5b26bf4a9fe20739ae9634fb7b530a24aac4f71ed32'),
  BMONI_PARTNER_ID: z.string().default('b7e6a1d0-4f3c-4c2a-9e8b-1a2b3c4d5e6f'),
  GEMINI_API_KEY: z.string().optional(),
});

export const env = envSchema.parse(process.env);

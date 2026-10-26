-- FlowPay: BMONI -> Stellar migration (M3)
-- Links each user to the Stellar account they proved ownership of.
-- Apply to Supabase / Postgres BEFORE deploying the M3 backend:
--   psql "$DATABASE_URL" -f prisma/sql/2026-10-26_add_stellar_account_id.sql
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS stellar_account_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS users_stellar_account_id_key ON public.users (stellar_account_id);

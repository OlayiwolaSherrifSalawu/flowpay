-- FlowPay Supabase Schema & Migration
-- Project Ref: mxjbzexlnenooclmaawe
-- Relational persistence for FlowPay business orchestration, employees, payroll, missions, webhooks, and audit logs.
-- Designed strictly following Supabase best practices (RLS, typed JSONB, performance indexes).

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.employees (
  id TEXT PRIMARY KEY,
  bmoni_user_id TEXT,
  partner_id TEXT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone_number TEXT,
  country TEXT NOT NULL,          -- 'NG', 'MX', 'CA', 'US', etc.
  target_currency TEXT NOT NULL,  -- 'NGN', 'MXN', 'USD', 'EUR', etc.
  payroll_amount_minor INTEGER NOT NULL DEFAULT 0,
  payroll_currency TEXT,
  wallet_id TEXT,
  wallet_address TEXT,
  card_id TEXT,
  status TEXT NOT NULL DEFAULT 'CREATED', -- 'CREATED', 'WALLET_PENDING', 'KYC_PENDING', 'ONBOARDING', 'READY', 'FAILED', 'LINKED', 'ACTIVE'
  failed_stage TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payroll_runs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  total_usd_minor INTEGER NOT NULL,  -- minor units ($100.00 -> 10000)
  fee_usd_minor INTEGER NOT NULL DEFAULT 0,
  employee_count INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'COMPLETED', -- 'DRAFT', 'PREVIEW', 'COMPLETED', 'FAILED'
  reference TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payroll_items (
  id TEXT PRIMARY KEY,
  payroll_run_id TEXT NOT NULL REFERENCES public.payroll_runs(id) ON DELETE CASCADE,
  employee_id TEXT NOT NULL,
  employee_name TEXT NOT NULL,
  country TEXT NOT NULL,
  target_currency TEXT NOT NULL,
  target_amount_minor INTEGER NOT NULL,
  usd_amount_minor INTEGER NOT NULL,
  exchange_rate NUMERIC(18,8) NOT NULL,
  status TEXT NOT NULL DEFAULT 'SUCCESS', -- 'SUCCESS', 'FAILED', 'PENDING'
  proposal_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.money_missions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  rule_type TEXT NOT NULL, -- 'AUTO_SWEEP', 'SPEND_CAP', 'EMERGENCY_RESERVE', 'FX_TARGET'
  condition_json JSONB NOT NULL,
  action_json JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_activity (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL, -- 'PERSONAL', 'BUSINESS', 'SYSTEM', 'AI'
  action TEXT NOT NULL,
  actor TEXT NOT NULL,
  details_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.webhook_events (
  id TEXT PRIMARY KEY,
  bmoni_event_id TEXT UNIQUE,
  event_type TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.webhook_subscriptions (
  id TEXT PRIMARY KEY,
  partner_id TEXT NOT NULL,
  callback_url TEXT NOT NULL,
  secret_key TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  events JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 2. Performance Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_employees_email ON public.employees(email);
CREATE INDEX IF NOT EXISTS idx_employees_bmoni_user_id ON public.employees(bmoni_user_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON public.employees(status);
CREATE INDEX IF NOT EXISTS idx_payroll_items_run ON public.payroll_items(payroll_run_id);
CREATE INDEX IF NOT EXISTS idx_payroll_items_employee ON public.payroll_items(employee_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_activity(created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_events_type ON public.webhook_events(event_type);

-- ---------------------------------------------------------------------------
-- 3. Row Level Security (RLS) - Supabase Standard
-- ---------------------------------------------------------------------------

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.money_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_subscriptions ENABLE ROW LEVEL SECURITY;

-- Service role policies (full backend access)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'employees' AND policyname = 'service_role_employees_all') THEN
    CREATE POLICY service_role_employees_all ON public.employees FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'payroll_runs' AND policyname = 'service_role_payroll_runs_all') THEN
    CREATE POLICY service_role_payroll_runs_all ON public.payroll_runs FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'payroll_items' AND policyname = 'service_role_payroll_items_all') THEN
    CREATE POLICY service_role_payroll_items_all ON public.payroll_items FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'money_missions' AND policyname = 'service_role_money_missions_all') THEN
    CREATE POLICY service_role_money_missions_all ON public.money_missions FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'audit_activity' AND policyname = 'service_role_audit_activity_all') THEN
    CREATE POLICY service_role_audit_activity_all ON public.audit_activity FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'webhook_events' AND policyname = 'service_role_webhook_events_all') THEN
    CREATE POLICY service_role_webhook_events_all ON public.webhook_events FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'webhook_subscriptions' AND policyname = 'service_role_webhook_subs_all') THEN
    CREATE POLICY service_role_webhook_subs_all ON public.webhook_subscriptions FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Authenticated read policies (for frontend / authenticated clients)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'employees' AND policyname = 'authenticated_employees_read') THEN
    CREATE POLICY authenticated_employees_read ON public.employees FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'payroll_runs' AND policyname = 'authenticated_payroll_runs_read') THEN
    CREATE POLICY authenticated_payroll_runs_read ON public.payroll_runs FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'payroll_items' AND policyname = 'authenticated_payroll_items_read') THEN
    CREATE POLICY authenticated_payroll_items_read ON public.payroll_items FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'money_missions' AND policyname = 'authenticated_money_missions_read') THEN
    CREATE POLICY authenticated_money_missions_read ON public.money_missions FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'audit_activity' AND policyname = 'authenticated_audit_activity_read') THEN
    CREATE POLICY authenticated_audit_activity_read ON public.audit_activity FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

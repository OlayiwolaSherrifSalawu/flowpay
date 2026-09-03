-- FlowPay Postgres Schema: Relational persistence for FlowPay metadata, business orchestration, and audit logs

CREATE TABLE IF NOT EXISTS employees (
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
  status TEXT NOT NULL DEFAULT 'CREATED', -- 6 stages: 'CREATED', 'WALLET_PENDING', 'KYC_PENDING', 'ONBOARDING', 'READY', 'FAILED'
  failed_stage TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payroll_runs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  total_usd_minor INTEGER NOT NULL,  -- integer minor units ($100.00 -> 10000)
  fee_usd_minor INTEGER NOT NULL DEFAULT 0,
  employee_count INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'COMPLETED', -- 'DRAFT', 'PREVIEW', 'COMPLETED', 'FAILED'
  reference TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payroll_items (
  id TEXT PRIMARY KEY,
  payroll_run_id TEXT NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
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

CREATE TABLE IF NOT EXISTS money_missions (
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

CREATE TABLE IF NOT EXISTS audit_activity (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL, -- 'PERSONAL', 'BUSINESS', 'SYSTEM', 'AI'
  action TEXT NOT NULL,
  actor TEXT NOT NULL,
  details_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY,
  bmoni_event_id TEXT UNIQUE,
  event_type TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS webhook_subscriptions (
  id TEXT PRIMARY KEY,
  partner_id TEXT NOT NULL,
  callback_url TEXT NOT NULL,
  secret_key TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  events TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
CREATE INDEX IF NOT EXISTS idx_employees_bmoni_user_id ON employees(bmoni_user_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_payroll_items_run ON payroll_items(payroll_run_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_activity(created_at);
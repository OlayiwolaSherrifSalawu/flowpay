-- FlowPay: BMONI -> Stellar migration (M5)
-- Payroll runs belong to an employer; items carry their real Stellar transaction hash.
ALTER TABLE public.payroll_runs ADD COLUMN IF NOT EXISTS employer_user_id TEXT;
CREATE INDEX IF NOT EXISTS idx_payroll_runs_employer ON public.payroll_runs (employer_user_id);
ALTER TABLE public.payroll_items ADD COLUMN IF NOT EXISTS transaction_hash TEXT;
ALTER TABLE public.payroll_items ADD COLUMN IF NOT EXISTS error_reason TEXT;

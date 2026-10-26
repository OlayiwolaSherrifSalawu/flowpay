-- FlowPay: BMONI -> Stellar migration (M4)
-- Invites are looked up by token hash only (never by email/id), and survive restarts.
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS invite_token_hash TEXT;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS invite_expires_at TIMESTAMPTZ;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS linked_user_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS employees_invite_token_hash_key ON public.employees (invite_token_hash);

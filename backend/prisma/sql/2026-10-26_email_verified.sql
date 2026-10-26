-- FlowPay: M8 auth. Email ownership must be proven (emailed code) before accepting an employee invite.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

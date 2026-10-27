-- SEP-2 federation: opt-in payment names (<handle>*<home domain>).
-- Apply manually to Supabase before deploying a backend that connects to it.
ALTER TABLE users ADD COLUMN IF NOT EXISTS stellar_handle TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS users_stellar_handle_key ON users (stellar_handle);

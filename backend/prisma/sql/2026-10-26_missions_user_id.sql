-- FlowPay: BMONI -> Stellar migration (M3b)
-- Missions belong to a user; previously every user saw every mission.
ALTER TABLE public.money_missions ADD COLUMN IF NOT EXISTS user_id TEXT;
CREATE INDEX IF NOT EXISTS idx_money_missions_user_id ON public.money_missions (user_id);

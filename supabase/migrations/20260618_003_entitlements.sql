-- HLTH V1.0 — Subscription entitlements.
--
-- Tracks user subscription tier (free/premium) and provider details.
-- INSERT/UPDATE restricted to service_role (server-side webhook handler
-- from Apple/Google IAP). Users can only read their own subscription.

CREATE TABLE public.subscriptions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tier        text        NOT NULL DEFAULT 'free',   -- 'free', 'premium'
  started_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz,
  is_active   boolean     NOT NULL DEFAULT true,
  provider    text,       -- 'apple', 'google', 'stripe'
  provider_id text,       -- external subscription ID
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own subscription.
CREATE POLICY "subscriptions self read"
  ON public.subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Writes are restricted to service_role (webhook handler).
-- No INSERT/UPDATE policies for anon/authenticated roles.

CREATE INDEX subscriptions_user_active_idx
  ON public.subscriptions(user_id, is_active);

CREATE TRIGGER subscriptions_touch
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- HLTH V1.0 — Consent ledger + geo_region on user_profiles.
--
-- Records every consent grant/revocation for audit trail and
-- geo-specific privacy law compliance (GDPR Art. 7, CCPA, PDPA, PIPL).

CREATE TABLE public.consent_records (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  consent_type    text        NOT NULL,     -- 'data_processing', 'health_data', 'analytics'
  granted         boolean     NOT NULL,
  granted_at      timestamptz NOT NULL DEFAULT now(),
  revoked_at      timestamptz,
  policy_version  text        NOT NULL,     -- semver or hash of the policy text
  geo_region      text        NOT NULL,     -- 'eu', 'us', 'th', 'cn', 'other'
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "consent self read"
  ON public.consent_records FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "consent self insert"
  ON public.consent_records FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "consent self update"
  ON public.consent_records FOR UPDATE
  USING (auth.uid() = user_id);

CREATE INDEX consent_user_type_idx
  ON public.consent_records(user_id, consent_type);

-- Quick-access geo_region on user_profiles (avoids join).
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS geo_region text DEFAULT 'other';

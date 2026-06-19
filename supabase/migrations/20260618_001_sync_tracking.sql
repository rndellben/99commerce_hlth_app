-- HLTH V1.0 — Sync tracking: add updated_at to tables that need
-- last-write-wins conflict resolution for the outbox cloud sync.

ALTER TABLE public.daily_metrics
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.baselines
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE TRIGGER daily_metrics_touch
  BEFORE UPDATE ON public.daily_metrics
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER baselines_touch
  BEFORE UPDATE ON public.baselines
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

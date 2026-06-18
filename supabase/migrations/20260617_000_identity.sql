-- HLTH V1.0 — Identity + Aggregated-Rollup tables.
--
-- Cloud schema for the first Supabase slice. Mirrors the local Drift
-- tables that need cross-device durability:
--   * users / user_profiles / devices   — identity (3 tables)
--   * daily_metrics / baselines         — aggregated rollups (2 tables)
--
-- Raw time-series tables (hr_samples, hrv_samples, spo2_samples, etc.)
-- stay local in V1.0 and will land in V1.1 via the outbox pattern.
--
-- RLS scopes every row to `auth.uid()` (uuid). DELETE policies are
-- intentionally omitted — account deletion cascades from `auth.users`.

-- ─── users ──────────────────────────────────────────────────────────────
create table public.users (
  id            uuid        primary key references auth.users(id) on delete cascade,
  email         text        unique,
  phone         text        unique,
  display_name  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

-- ─── user_profiles ──────────────────────────────────────────────────────
create table public.user_profiles (
  user_id                 uuid     primary key references public.users(id) on delete cascade,
  date_of_birth           date,
  sex_at_birth            smallint not null default 2,  -- 0=female 1=male 2=unknown
  height_cm               real,
  weight_kg               real,
  uses_metric             boolean  not null default true,
  uses_24h_clock          boolean  not null default true,
  resting_hr_baseline     int,
  cycle_tracking_enabled  boolean  not null default false,
  last_period_start_date  date,
  typical_cycle_length    int,
  accepted_at_utc         timestamptz,          -- GDPR consent timestamp (V1.0 minimal)
  updated_at              timestamptz not null default now()
);

-- ─── devices ────────────────────────────────────────────────────────────
create table public.devices (
  id                    uuid        primary key,
  user_id               uuid        not null references public.users(id) on delete cascade,
  mac_address           text        unique,
  ios_peripheral_uuid   text,
  display_name          text        not null,
  model                 text,
  hardware_version      text,
  firmware_version      text,
  user_id_on_band       text,
  paired_at             timestamptz not null,
  last_connected_at     timestamptz,
  last_battery_percent  int,
  last_charging         boolean,
  is_active             boolean     not null default true,
  capabilities          jsonb       not null default '{}'::jsonb,
  deleted_at            timestamptz
);
create index devices_user_id_idx on public.devices(user_id);

-- ─── daily_metrics ──────────────────────────────────────────────────────
-- 1 row per (user, local_date). Cheap to push (~365/yr/user).
create table public.daily_metrics (
  id                        uuid        primary key,
  user_id                   uuid        not null references public.users(id) on delete cascade,
  local_date                date        not null,
  tz_offset_min             int         not null,
  -- Cardiac
  resting_hr_bpm            int,
  hrv_rmssd_ms              real,
  hrv_sdnn_ms               real,
  resting_resp_rate_bpm     real,
  -- SpO2
  spo2_overnight_avg        real,
  spo2_overnight_min        int,
  -- BP
  systolic_mmhg             int,
  diastolic_mmhg            int,
  -- Sleep
  sleep_total_min           int,
  sleep_deep_pct            real,
  sleep_rem_pct             real,
  sleep_light_pct           real,
  sleep_efficiency_pct      real,
  bedtime_utc               timestamptz,
  wake_utc                  timestamptz,
  -- Activity
  steps                     int,
  distance_m                int,
  calories_kcal             real,
  active_minutes            int,
  -- Vascular / cardiac advanced
  stiffness_index           real,
  augmentation_index        real,
  stroke_volume_index       real,
  breathing_disruptions_hr  real,
  -- Scores
  recovery_score            int,
  wellness_score            int,
  -- Cycle
  cycle_phase               smallint,
  -- Provenance
  computed_at               timestamptz not null default now(),
  algorithm_version         text        not null,
  source                    smallint    not null,
  deleted_at                timestamptz,
  unique (user_id, local_date)
);
create index daily_metrics_user_date_idx on public.daily_metrics(user_id, local_date desc);

-- ─── baselines ──────────────────────────────────────────────────────────
-- Rolling 14/30/90-day mean+stddev per metric. Tiny per user.
create table public.baselines (
  id                  uuid        primary key,
  user_id             uuid        not null references public.users(id) on delete cascade,
  metric_key          text        not null,
  window_days         int         not null,
  computed_for_date   date        not null,
  mean_value          real        not null,
  stddev_value        real        not null,
  sample_count        int         not null,
  computed_at         timestamptz not null default now(),
  algorithm_version   text        not null,
  unique (user_id, metric_key, window_days, computed_for_date)
);
create index baselines_user_metric_idx
  on public.baselines(user_id, metric_key, window_days, computed_for_date desc);

-- ─── Row-Level Security ─────────────────────────────────────────────────
alter table public.users           enable row level security;
alter table public.user_profiles   enable row level security;
alter table public.devices         enable row level security;
alter table public.daily_metrics   enable row level security;
alter table public.baselines       enable row level security;

-- users (scoped by `id` which equals auth.uid())
create policy "users self read"   on public.users for select using (auth.uid() = id);
create policy "users self insert" on public.users for insert with check (auth.uid() = id);
create policy "users self update" on public.users for update using (auth.uid() = id) with check (auth.uid() = id);

-- user_profiles
create policy "user_profiles self read"   on public.user_profiles for select using (auth.uid() = user_id);
create policy "user_profiles self insert" on public.user_profiles for insert with check (auth.uid() = user_id);
create policy "user_profiles self update" on public.user_profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- devices
create policy "devices self read"   on public.devices for select using (auth.uid() = user_id);
create policy "devices self insert" on public.devices for insert with check (auth.uid() = user_id);
create policy "devices self update" on public.devices for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- daily_metrics
create policy "daily_metrics self read"   on public.daily_metrics for select using (auth.uid() = user_id);
create policy "daily_metrics self insert" on public.daily_metrics for insert with check (auth.uid() = user_id);
create policy "daily_metrics self update" on public.daily_metrics for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- baselines
create policy "baselines self read"   on public.baselines for select using (auth.uid() = user_id);
create policy "baselines self insert" on public.baselines for insert with check (auth.uid() = user_id);
create policy "baselines self update" on public.baselines for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─── touch_updated_at trigger ───────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_touch
  before update on public.users
  for each row execute function public.touch_updated_at();

create trigger user_profiles_touch
  before update on public.user_profiles
  for each row execute function public.touch_updated_at();

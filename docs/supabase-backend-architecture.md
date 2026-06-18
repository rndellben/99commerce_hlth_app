# HLTH Supabase Backend Architecture

> Version 1.0 | Built 2026-06-18 | Commit `c0a8da6`
>
> Authors: HLTH Engineering Team
>
> Supabase Project: `cslejebgczfhocmgcnbg` (Frankfurt, eu-central-1)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [System Diagram](#system-diagram)
4. [Data Flow](#data-flow)
5. [Phase 1: Connection Infrastructure](#phase-1-connection-infrastructure)
6. [Phase 2: Cloud Sync (Outbox Pattern)](#phase-2-cloud-sync-outbox-pattern)
7. [Phase 3: Geo-Specific Privacy Configuration](#phase-3-geo-specific-privacy-configuration)
8. [Phase 4: Free vs Paid Feature Gating](#phase-4-free-vs-paid-feature-gating)
9. [Phase 5: Auth Recovery & Resilience](#phase-5-auth-recovery--resilience)
10. [Database Schema](#database-schema)
11. [Edge Functions](#edge-functions)
12. [File Reference](#file-reference)
13. [Setup Guide](#setup-guide)
14. [Deployment Checklist](#deployment-checklist)
15. [Testing & QA](#testing--qa)
16. [Decision Log](#decision-log)
17. [Changelog](#changelog)

---

## Executive Summary

The HLTH app backend is built on **Supabase** (not Firebase — ~10x cheaper at scale for health data workloads). The architecture is **offline-first**: all health data is collected from the H59 smartband via BLE, processed and stored locally in Drift SQLite, then synced to Supabase when connectivity is available.

This document covers the five systems built on 2026-06-18:

| System | Purpose | Status |
|--------|---------|--------|
| Connection Infrastructure | Network monitoring, retry logic, UI indicator | Production-ready |
| Cloud Sync (Outbox) | Reliable local-to-cloud data sync | Production-ready |
| Geo-Privacy Configuration | Region-aware consent and data handling | Production-ready |
| Free/Paid Feature Gating | On-device free vs server-side premium | Production-ready |
| Auth Recovery | Token refresh resilience | Production-ready |

**Key numbers:**
- 17 new files created, 10 existing files modified
- 3 Supabase migrations, 1 Edge Function
- 0 errors on `flutter analyze`
- Zero breaking changes to existing features

---

## Architecture Overview

### Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Flutter (Dart) | Cross-platform mobile app |
| State Management | Riverpod | Reactive, lazy provider system |
| Local Database | Drift (SQLite) | Typed ORM, offline-first storage |
| Cloud Backend | Supabase (PostgreSQL) | Auth, PostgREST, Edge Functions |
| BLE | QCBandSDK (iOS) / QRing (Android) | H59 band communication |
| Models | Freezed | Immutable domain objects |

### What Syncs to the Cloud (V1.0)

| Table | Description | Volume |
|-------|-------------|--------|
| `daily_metrics` | 1 aggregated row per user per day | ~365 rows/yr/user |
| `baselines` | Rolling 14/30/90-day statistical baselines | ~27 rows/user (9 metrics x 3 windows) |
| `devices` | Paired band metadata | 1-2 rows/user |
| `user_profiles` | User preferences and biometrics | 1 row/user |
| `consent_records` | Consent audit trail | ~2-3 rows/user |

### What Stays Local Only (V1.0)

Raw time-series data stays on-device for privacy and cost reasons:
- `hr_samples`, `hrv_samples`, `spo2_samples`, `bp_readings`, `stress_samples`
- `step_buckets`, `sleep_sessions`, `sleep_epochs`
- `sync_state` watermarks
- `cloud_sync_outbox` (transient queue)

### Supabase Services Used

| Service | Used For | Status |
|---------|----------|--------|
| Auth | Email/password signup, JWT tokens, secure refresh | Active |
| PostgREST | CRUD for all cloud tables via RLS | Active |
| Edge Functions | Premium server-side compute (health insights) | Stub ready |
| Realtime | Push notifications to connected clients | Reserved for V1.1 |
| Storage | File/image storage | Not used |

---

## System Diagram

```
+------------------------------------------------------------------+
|                        SUPABASE (Frankfurt)                       |
|                                                                   |
|   +-----------+  +-------------+  +------------+  +----------+   |
|   | Auth      |  | PostgREST   |  | Edge Fns   |  | Realtime |   |
|   | (GoTrue)  |  | (RLS)       |  | (Deno)     |  | (V1.1)   |   |
|   +-----------+  +-------------+  +------------+  +----------+   |
|                                                                   |
|   TABLES:                                                         |
|   users | user_profiles | devices | daily_metrics | baselines     |
|   consent_records | subscriptions                                 |
+----------------------------+--------------------------------------+
                             |
                    HTTPS (JWT auth)
                    Retry w/ backoff
                             |
+----------------------------+--------------------------------------+
|                     FLUTTER APP (Mobile)                          |
|                                                                   |
|  LAYER 1: INFRASTRUCTURE                                         |
|  +---------------------+    +-------------------------------+     |
|  | ConnectivityService  |    | SupabaseConnectionMonitor     |    |
|  | - connectivity_plus  +--->| - supabaseReadyProvider       |    |
|  | - DNS probe (3s)     |    | - connectionHealthProvider    |    |
|  | - 500ms debounce     |    | - withRetry() utility         |    |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  LAYER 2: DATA SYNC                                               |
|  +---------------------+    +-------------------------------+     |
|  | Band Sync Pipeline   |    | Cloud Sync Pipeline           |    |
|  |                      |    |                               |     |
|  | BleService (BLE)     |    | CloudSyncOutboxRepo (queue)   |     |
|  |   -> SyncAdapters    |    |   -> SupabaseSyncRepo (push)  |     |
|  |   -> SyncService     +--->|   -> CloudSyncService (orch)  |     |
|  |   -> DailyAggregator |    |                               |     |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  LAYER 3: BUSINESS RULES                                         |
|  +---------------------+    +-------------------------------+     |
|  | Geo Config           |    | Feature Gate                  |     |
|  | - RegionDetector     |    | - FeatureGate (days + tier)   |     |
|  | - GeoConfig presets  |    | - EntitlementService          |     |
|  | - ConsentService     |    | - ServerInsightsService       |     |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  LAYER 4: AUTH                                                    |
|  +---------------------+                                         |
|  | AuthRecovery         |    +-------------------------------+    |
|  | - Token refresh      |    | ConnectionIndicator (UI)      |    |
|  | - Soft re-auth flag  |    | - Green / Amber / Red dot     |    |
|  +---------------------+    +-------------------------------+    |
+------------------------------------------------------------------+
```

---

## Data Flow

### Band-to-Cloud Pipeline (Every ~30 Minutes)

```
  H59 Band
     |
     | BLE (platform channel)
     v
  BleService.getHrHistory(), getSleepHistory(), etc.
     |
     v
  SyncAdapters: hrFromNative(), sleepFromNative(), etc.
     |  (converts legacy band shapes -> canonical freezed models)
     v
  Repositories: hrRepo.insertMany(), sleepRepo.createSession(), etc.
     |  (persists to local Drift SQLite, idempotent upsert)
     v
  DailyAggregator.aggregateRecent()
     |  (rolls up samples into daily_metrics for last 14 days)
     v
  CloudSyncService.enqueueRecentMetrics()
     |  (queues dirty daily_metrics + baselines into outbox)
     v
  CloudSyncService.processOutbox()
     |  (drains outbox, pushes each row to Supabase via PostgREST)
     v
  SupabaseSyncRepository.pushDailyMetrics()
     |  (upsert with retry, maps local-user-v1 -> auth UUID)
     v
  Supabase PostgreSQL (RLS enforced)
```

### Auth Flow

```
  App Launch
     |
     v
  Supabase.initialize() (main.dart)
     |  - SecureAuthStorage (Keychain / EncryptedSharedPrefs)
     |  - Auto-refresh enabled
     v
  Router Redirect Chain:
     1. /debug always allowed
     2. Auth gate: signed out? -> /auth
     3. Profile gate: no profile? -> /onboarding
     4. Consent gate: geo requires consent & not granted? -> /onboarding
     5. Normal navigation
```

---

## Phase 1: Connection Infrastructure

### ConnectivityService

**File:** `lib/core/services/connectivity_service.dart`

Monitors device network state using `connectivity_plus` with DNS lookup confirmation.

**How it works:**
1. Listens to `connectivity_plus` radio state changes (wifi, mobile, none)
2. Debounces 500ms to avoid rapid flapping during network transitions
3. Confirms actual reachability with `InternetAddress.lookup('dns.google')` (3s timeout)
4. Emits `ConnectivityStatus.online` or `ConnectivityStatus.offline`

**Why DNS probe instead of just radio state:**
Radio can report "connected" while behind a captive portal or with no internet. The DNS probe catches this.

| Provider | Type | Description |
|----------|------|-------------|
| `connectivityServiceProvider` | `Provider<ConnectivityService>` | Singleton service |
| `connectivityStateProvider` | `StreamProvider<ConnectivityStatus>` | Reactive stream |

### SupabaseConnectionMonitor

**File:** `lib/core/services/supabase_connection_monitor.dart`

Combines network state with auth token validity into a single health signal.

| Provider | Type | Description |
|----------|------|-------------|
| `supabaseReadyProvider` | `Provider<bool>` | `true` when online AND authenticated |
| `connectionHealthProvider` | `Provider<ConnectionHealth>` | `connected` / `offline` / `authExpired` |

**Retry Utility — used by all Supabase calls:**
```dart
final result = await SupabaseConnectionMonitor.withRetry(() async {
  return await supabase.from('daily_metrics').upsert(data);
}, maxAttempts: 3);
// Exponential backoff: 200ms -> 400ms -> 800ms (with jitter)
```

### ConnectionIndicator Widget

**File:** `lib/ui/widgets/connection_indicator.dart`

Small colored dot displayed in the home screen app bar, next to the BLE connection chip:

| Color | State | Meaning |
|-------|-------|---------|
| Green | `connected` | Online, authenticated, cloud sync working |
| Amber | `offline` | No internet, app works in local-only mode |
| Red | `authExpired` | Token expired, needs re-authentication |

---

## Phase 2: Cloud Sync (Outbox Pattern)

### Why Outbox Pattern?

Direct pushes to Supabase would fail silently when offline and lose data. The outbox pattern guarantees eventual delivery:
- Writes always succeed (to local SQLite)
- Pushes are retried automatically
- Survives app restarts (outbox is persisted)
- Deduplicates (same record won't be queued twice)

### How It Works

```
Band Sync Complete
       |
       v
DailyAggregator.aggregateRecent()
       |
       v
CloudSyncService.enqueueRecentMetrics()    <-- Queues dirty rows
CloudSyncService.enqueueIdentity()         <-- Queues device + profile
       |
       v
[CloudSyncOutbox table in local SQLite]    <-- Survives app restarts
       |
       v
CloudSyncService.processOutbox()           <-- Runs on:
       |                                        - Every periodic tick (~30min)
       |                                        - Every band connect event
       v
SupabaseSyncRepository.pushXxx()           <-- PostgREST upsert + retry
       |
       v
CloudSyncOutboxRepo.dequeue()             <-- Removed on success
```

### Outbox Table Schema (Local Drift SQLite)

```
CloudSyncOutbox (schema v3)
  id               TEXT PK      -- UUID v4
  target_table     TEXT         -- 'daily_metrics', 'baselines', 'devices', 'user_profiles'
  record_id        TEXT         -- PK of the record to push
  created_at_utc   INTEGER     -- Unix seconds (FIFO ordering)
  attempts         INTEGER     -- Retry counter (default 0)
  last_attempt_at  INTEGER?    -- Last attempt timestamp
  last_error       TEXT?       -- Last failure message
```

### Deduplication

`enqueue()` checks for an existing entry with the same `target_table` + `record_id` before inserting. Safe to call repeatedly — won't create duplicates.

### Failure Handling

| Scenario | Behavior |
|----------|----------|
| Network offline | `processOutbox()` returns early, outbox preserved |
| Single push fails | `attempts` incremented, error recorded, next entry processed |
| 10+ consecutive failures | Entry purged by `purgeStaleFailed()` |
| App crash mid-sync | Outbox entries persist in SQLite, retried on next launch |
| Band sync fails | Cloud enqueue wrapped in try/catch, never breaks band sync |

### User ID Bridging (V1 Decision)

All local Drift data uses `userId = 'local-user-v1'` (a hardcoded local identifier). When pushing to Supabase, the `SupabaseSyncRepository` substitutes the real Supabase `auth.uid()` UUID. This keeps local data isolated from auth state.

**Future (V2):** Migrate all local rows to the auth UUID on first sign-in for cleaner identity.

### Upsert Conflict Targets

Each table has a natural uniqueness constraint that the upsert targets:

| Table | Conflict Target | Why |
|-------|----------------|-----|
| `daily_metrics` | `(user_id, local_date)` | One rollup per user per day |
| `baselines` | `(user_id, metric_key, window_days, computed_for_date)` | One baseline per metric/window/date |
| `devices` | `(id)` | PK upsert |
| `user_profiles` | `(user_id)` | PK upsert |

### Key Files

| File | Purpose |
|------|---------|
| `lib/core/repositories/cloud_sync_outbox_repository.dart` | Local outbox CRUD (enqueue, dequeue, retry, purge) |
| `lib/core/repositories/supabase_sync_repository.dart` | PostgREST push logic (4 upsert methods, manual map builders) |
| `lib/core/services/cloud_sync_service.dart` | Orchestrator (enqueue + processOutbox) |
| `lib/core/services/sync_service.dart` | Wiring point (calls cloud sync after band sync) |

---

## Phase 3: Geo-Specific Privacy Configuration

### Why Geo-Aware?

Different countries have different data privacy laws. A health app that collects biometric data must comply with each jurisdiction's rules or face legal liability:

| Regulation | Region | Key Requirement |
|-----------|--------|----------------|
| GDPR | EU/EEA/UK | Explicit opt-in consent before any data processing |
| CCPA | California/US | Right to delete, disclosure of data practices |
| PDPA | Thailand | Explicit consent, data breach notification |
| PIPL | China | Explicit consent, cross-border transfer notice |

### Supported Regions

| Region | Regulation | Explicit Consent | Min Age | Max Retention | Right to Delete |
|--------|-----------|-----------------|---------|---------------|-----------------|
| EU | GDPR | Yes | 16 | 3 years | Yes |
| US | CCPA | No | 13 | 5 years | Yes |
| Thailand | PDPA | Yes | 13 | 3 years | Yes |
| China | PIPL | Yes | 14 | 2 years | Yes |
| Other | EU-strict fallback | Yes | 13 | 3 years | Yes |

**Default is EU-strict** — safest for unknown regions.

### Region Detection

**File:** `lib/core/config/region_detector.dart`

Detection priority:
1. **Explicit user override** — stored in SharedPreferences, set during onboarding or settings
2. **Device locale** — `Platform.localeName` parsed to ISO 3166-1 alpha-2 country code
3. **Fallback** — `GeoRegion.other` (EU-strict defaults)

**Country code coverage:** 31 EU/EEA/UK codes, 5 US territories, TH, CN (40 total).

| Provider | Type | Description |
|----------|------|-------------|
| `detectedRegionProvider` | `FutureProvider<GeoRegion>` | Auto-detected or overridden region |
| `geoConfigProvider` | `Provider<GeoConfig>` | Fully-resolved config for current region |

### Consent System

**File:** `lib/core/services/consent_service.dart`

**Required consent types by region:**

| Region Type | Required Consents |
|-------------|------------------|
| Explicit consent regions (EU, TH, CN, Other) | `data_processing` + `health_data` |
| Non-explicit regions (US) | `health_data` only |

**Dual storage for resilience:**
- **Local:** SharedPreferences (offline access, instant checks)
- **Cloud:** `consent_records` table in Supabase (legal audit trail)

**Policy versioning:** All consent is tagged with `kCurrentPolicyVersion` (currently `'1.0.0'`). When the privacy policy text changes, bump this constant — users who consented to an older version will be re-prompted automatically.

### Consent UI Flow

```
Onboarding Screen (PageView)
  |
  +-- Page 0: Welcome
  +-- Page 1: Profile (DOB, sex, height, weight, units, clock)
  +-- Page 2: Cycle tracking (if sex=female)
  +-- Page 3: Data & Privacy consent (if region requires explicit consent)  <-- NEW
  |     [x] Data processing consent
  |     [x] Health data consent
  |     Shows: regulation label (GDPR/PDPA/PIPL), data residency region
  +-- Page 4: Disclaimer ("I understand this is not medical advice")
  |
  v
_submit() -> consentService.recordConsent() -> SharedPreferences + Supabase
```

### Router Consent Gate

In `lib/core/routing/router.dart`, a new redirect check runs after the profile gate:

```dart
// If geo requires explicit consent and user hasn't granted it,
// redirect back to onboarding (which shows the consent page)
if (geoConfig.requiresExplicitConsent) {
  final hasConsent = ref.read(hasRequiredConsentProvider).valueOrNull ?? true;
  if (!hasConsent && !atOnboarding && loc != '/privacy') {
    return '/onboarding';
  }
}
```

### Consent Records Schema (Supabase)

```sql
consent_records
  id              uuid PK (auto-generated)
  user_id         uuid FK -> users(id) ON DELETE CASCADE
  consent_type    text       -- 'data_processing', 'health_data', 'analytics'
  granted         boolean    -- true = granted, false = denied
  granted_at      timestamptz
  revoked_at      timestamptz (null = still active)
  policy_version  text       -- '1.0.0' (semver)
  geo_region      text       -- 'eu', 'us', 'th', 'cn', 'other'
  created_at      timestamptz

RLS: users can only read/insert/update their own records
Index: (user_id, consent_type)
```

---

## Phase 4: Free vs Paid Feature Gating

### On-Device (Free) Metrics

These run entirely on the device. No server calls, no subscription needed.

| Metric | Data Source | Processing |
|--------|-----------|------------|
| Heart rate (resting, live, historical) | H59 band | Local aggregator |
| SpO2 (overnight avg/min) | H59 band | Local aggregator |
| Sleep (duration, stages, efficiency) | H59 band | Local aggregator |
| Steps / distance / calories | H59 band | Direct from band |
| HRV (RMSSD, SDNN, PNN50) | H59 band | Local HRV calculator |
| Stress score (0-100) | H59 band | Band-derived (pressure feature) |
| Blood pressure (estimate) | H59 band | Band sensor |
| Recovery score (0-100) | Local baselines | 14-day baseline math |
| Fall detection | Accelerometer | Local 3-window state machine |
| Respiratory rate | PPG signal | Local signal processing |

### Server-Side (Premium) Features

These require cloud data + the Supabase Edge Function + an active premium subscription.

| Feature | Why Server-Side | Minimum Days | Gate Name |
|---------|----------------|-------------|-----------|
| AI health insights | LLM inference, cross-metric reasoning | 0 | `aiInsights` |
| Advanced sleep analysis | Multi-night pattern detection | 7 | `advancedSleepScoring` |
| Cross-metric correlations | Needs all metrics in one place | 14 | `crossMetricCorrelations` |
| Health risk predictions | Population-level baselines | 30 | `healthRiskPredictions` |
| Trend analysis (30/90 day) | Long-term historical aggregation | 90 | `trendAnalysis` |

### Subscription Model

**Supabase table:** `subscriptions`

```sql
subscriptions
  id          uuid PK (auto-generated)
  user_id     uuid FK -> users(id) ON DELETE CASCADE
  tier        text     -- 'free' or 'premium'
  started_at  timestamptz
  expires_at  timestamptz (null = never expires)
  is_active   boolean  -- false = cancelled
  provider    text     -- 'apple', 'google', 'stripe'
  provider_id text     -- external subscription ID for reconciliation
  created_at  timestamptz
  updated_at  timestamptz (auto-touched on update)
```

**Security:** Users can only READ their own subscription. INSERT/UPDATE is restricted to `service_role` (server-side webhook handler from Apple/Google IAP). This prevents users from granting themselves premium access.

### EntitlementService

**File:** `lib/core/services/entitlement_service.dart`

| Step | What Happens |
|------|-------------|
| App start | Fetches active subscription from Supabase |
| Success | Caches tier + expiry in SharedPreferences |
| Offline | Falls back to cached values |
| Auth change | Re-fetches (sign-in, token refresh) |
| Expiration | `effectiveTier` returns `free` if `expiresAt` is in the past |

### FeatureGate Integration

**File:** `lib/core/services/feature_gate.dart`

The existing `FeatureGate` class now combines **day-based** gates (how long the user has worn the band) with **tier-based** gates (free vs premium):

```dart
class FeatureGate {
  FeatureGate({
    required this.daysSinceFirstWear,
    this.baselineEstablished = const {},
    this.tier = SubscriptionTier.free,  // NEW
  });

  // Day 0 — always free
  bool get heartRate => true;
  bool get spo2 => true;
  bool get steps => true;

  // Day 14 — free, needs baselines
  bool get recoveryScore => daysSinceFirstWear >= 14 && _baseline('hr') && _baseline('hrv');

  // Premium — requires subscription + day threshold
  bool get aiInsights => _isPremium;
  bool get advancedSleepScoring => _isPremium && daysSinceFirstWear >= 7;
  bool get healthRiskPredictions => _isPremium && daysSinceFirstWear >= 30;
  bool get crossMetricCorrelations => _isPremium && daysSinceFirstWear >= 14;
  bool get trendAnalysis => _isPremium && longTermTrends;
}
```

### Edge Function: health-insights

**File:** `supabase/functions/health-insights/index.ts`

**Request pipeline:**

```
Client Request (with JWT)
    |
    v
1. Validate JWT -> 401 if invalid
    |
    v
2. Query subscriptions table -> 403 if not premium or expired
    |
    v
3. Fetch daily_metrics (last 30 days)
    |
    v
4. Fetch baselines (latest per metric)
    |
    v
5. Generate insights (stub — real ML is future workstream)
    |
    v
6. Return InsightsResult JSON
```

**Flutter client:** `lib/core/services/server_insights_service.dart`
- Calls `supabase.functions.invoke('health-insights')`
- Parses typed `InsightsResult` with `List<HealthInsight>`
- Uses `withRetry` for network resilience
- Gated behind `featureGate.aiInsights` (defense in depth — both client and server check)

---

## Phase 5: Auth Recovery & Resilience

**File:** `lib/core/auth/auth_recovery.dart`

### Problem

Supabase JWT tokens expire. If a refresh fails (network blip, server outage), the app shouldn't crash or lose local data. It should degrade gracefully and recover automatically.

### Solution

```
Normal Operation
     |
     v
API call returns 401
     |
     v
AuthRecovery.onAuthError()
     |
     v
Attempt refreshSession() (up to 3 times)
     |
     +-- Success: reset counter, resume normal operation
     |
     +-- 3 consecutive failures:
           |
           v
         Set needsReAuth = true
           |
           v
         connectionHealthProvider -> authExpired (red dot)
           |
           v
         Router can show soft re-auth overlay
         (local data preserved, not a hard logout)
```

### Key Behaviors

| Event | Response |
|-------|----------|
| Successful token refresh | Reset failure counter |
| Explicit sign-out | Reset counter (not a failure) |
| API returns 401 | Attempt manual `refreshSession()` |
| 3 consecutive refresh failures | Flag `needsReAuth = true` |
| User signs in again | Counter resets, flag clears |

| Provider | Type | Description |
|----------|------|-------------|
| `authRecoveryProvider` | `Provider<AuthRecovery>` | Singleton recovery monitor |
| `needsReAuthProvider` | `StreamProvider<bool>` | Emits `true` when re-auth needed |

---

## Database Schema

### Supabase Cloud Tables (PostgreSQL)

All tables enforce **Row-Level Security (RLS)** scoped to `auth.uid() = user_id`. DELETE policies are intentionally omitted — account deletion cascades from `auth.users`.

```
users                     (Migration 000)
  id              uuid PK (= auth.users.id)
  email           text UNIQUE
  phone           text UNIQUE
  display_name    text
  created_at      timestamptz
  updated_at      timestamptz (auto-touched)
  deleted_at      timestamptz

user_profiles             (Migration 000 + 002)
  user_id         uuid PK -> users
  date_of_birth   date
  sex_at_birth    smallint (0=female, 1=male, 2=unknown)
  height_cm       real
  weight_kg       real
  uses_metric     boolean (default true)
  uses_24h_clock  boolean (default true)
  resting_hr_baseline int
  cycle_tracking_enabled boolean
  last_period_start_date date
  typical_cycle_length int
  accepted_at_utc timestamptz
  geo_region      text (default 'other')     <-- Added in Migration 002
  updated_at      timestamptz

devices                   (Migration 000)
  id              uuid PK
  user_id         uuid -> users
  mac_address     text UNIQUE
  ios_peripheral_uuid text
  display_name    text
  model, hardware_version, firmware_version text
  paired_at       timestamptz
  last_connected_at timestamptz
  last_battery_percent int
  is_active       boolean
  capabilities    jsonb

daily_metrics             (Migration 000 + 001)
  id              uuid PK
  user_id         uuid -> users
  local_date      date UNIQUE(user_id, local_date)
  30+ metric columns (cardiac, spo2, bp, sleep, activity, scores)
  updated_at      timestamptz                <-- Added in Migration 001

baselines                 (Migration 000 + 001)
  id              uuid PK
  user_id         uuid -> users
  metric_key      text
  window_days     int (14, 30, 90)
  UNIQUE(user_id, metric_key, window_days, computed_for_date)
  updated_at      timestamptz                <-- Added in Migration 001

consent_records           (Migration 002)
  id              uuid PK
  user_id         uuid -> users
  consent_type    text
  granted         boolean
  granted_at, revoked_at timestamptz
  policy_version  text
  geo_region      text

subscriptions             (Migration 003)
  id              uuid PK
  user_id         uuid -> users
  tier            text ('free'/'premium')
  started_at, expires_at timestamptz
  is_active       boolean
  provider        text ('apple'/'google'/'stripe')
  provider_id     text
```

### Local Drift SQLite Tables

All existing tables (14) plus the new outbox:

```
cloud_sync_outbox         (Schema v3)
  id               text PK
  target_table     text
  record_id        text
  created_at_utc   integer
  attempts         integer (default 0)
  last_attempt_at_utc integer?
  last_error       text?
```

### Migration History

| Migration File | Version | Changes |
|---------------|---------|---------|
| `20260617_000_identity.sql` | V1.0 | Base schema: 5 tables + RLS + trigger |
| `20260618_001_sync_tracking.sql` | V1.0 | `updated_at` on daily_metrics + baselines |
| `20260618_002_consent_geo.sql` | V1.0 | `consent_records` table + `geo_region` column |
| `20260618_003_entitlements.sql` | V1.0 | `subscriptions` table |

---

## Edge Functions

| Function | Path | Auth | Subscription | Purpose |
|----------|------|------|-------------|---------|
| `health-insights` | `supabase/functions/health-insights/index.ts` | JWT required | Premium only | Health insight generation (stub) |

**Deploy:** `supabase functions deploy health-insights`

**Local dev:** `supabase functions serve` then test with:
```bash
curl -X POST http://localhost:54321/functions/v1/health-insights \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json"
```

---

## File Reference

### New Files (17)

| File | Layer | Purpose |
|------|-------|---------|
| `lib/core/services/connectivity_service.dart` | Infrastructure | Online/offline detection with DNS probe |
| `lib/core/services/supabase_connection_monitor.dart` | Infrastructure | Auth-aware connection health + retry utility |
| `lib/ui/widgets/connection_indicator.dart` | UI | Green/amber/red status dot |
| `lib/core/repositories/cloud_sync_outbox_repository.dart` | Data | Local outbox queue CRUD |
| `lib/core/repositories/supabase_sync_repository.dart` | Data | PostgREST upsert for 4 entity types |
| `lib/core/services/cloud_sync_service.dart` | Service | Outbox enqueue + drain orchestrator |
| `lib/core/config/geo_config.dart` | Config | GeoRegion enum + GeoConfig presets |
| `lib/core/config/region_detector.dart` | Config | Locale-based region detection + override |
| `lib/core/services/consent_service.dart` | Service | Consent grant/revoke/check + audit trail |
| `lib/core/models/entitlement.dart` | Model | SubscriptionTier enum + Entitlement freezed model |
| `lib/core/services/entitlement_service.dart` | Service | Subscription fetch from Supabase + offline cache |
| `lib/core/services/server_insights_service.dart` | Service | Edge Function client for premium insights |
| `lib/core/auth/auth_recovery.dart` | Auth | Token refresh failure detection + recovery |
| `supabase/migrations/20260618_001_sync_tracking.sql` | Migration | updated_at columns + triggers |
| `supabase/migrations/20260618_002_consent_geo.sql` | Migration | consent_records table + geo_region |
| `supabase/migrations/20260618_003_entitlements.sql` | Migration | subscriptions table |
| `supabase/functions/health-insights/index.ts` | Edge Function | Premium health insights stub |

### Modified Files (10)

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `connectivity_plus: ^6.1.0` |
| `lib/core/database/tables.dart` | Added `CloudSyncOutbox` table definition |
| `lib/core/database/app_database.dart` | Schema v3, registered outbox, v2->v3 migration |
| `lib/core/repositories/daily_metrics_repository.dart` | Added `getById()` method |
| `lib/core/repositories/baseline_repository.dart` | Added `getById()` method |
| `lib/core/services/sync_service.dart` | Wired cloud sync into SyncService + PeriodicSyncCoordinator |
| `lib/core/services/feature_gate.dart` | Added `tier` field + 5 premium feature gates |
| `lib/features/home/home_screen.dart` | Added ConnectionIndicator to app bar |
| `lib/features/onboarding/onboarding_screen.dart` | Added geo-aware consent page |
| `lib/core/routing/router.dart` | Added consent gate redirect |

### Documentation

| File | Content |
|------|---------|
| `docs/supabase-backend-architecture.md` | This document |

---

## Setup Guide

### Prerequisites

- Flutter SDK 3.8.1+
- A Supabase project (free tier works)
- Android device or emulator with USB debugging

### Step 1: Environment File

Create `hlth.env.json` in the project root (gitignored):

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi...",
  "FLAVOR": "dev"
}
```

Get these values from: **Supabase Dashboard > Settings > API > Project API keys**

Use the `anon` `public` key. Never use the `service_role` `secret` key in client code.

### Step 2: Apply Migrations

In the **Supabase SQL Editor** (Dashboard > SQL Editor > New Query), run each migration file in order:

1. `supabase/migrations/20260617_000_identity.sql` (if not already applied)
2. `supabase/migrations/20260618_001_sync_tracking.sql`
3. `supabase/migrations/20260618_002_consent_geo.sql`
4. `supabase/migrations/20260618_003_entitlements.sql`

Each should return "Success. No rows returned."

### Step 3: Auth Settings

For development, disable email confirmation:
- **Dashboard > Authentication > Providers > Email**
- Turn OFF "Confirm email"

### Step 4: Run

```bash
flutter pub get
flutter run --dart-define-from-file=hlth.env.json
```

### Step 5: Create Account

1. App opens to `/auth` screen
2. Tap "Create account"
3. Enter any email + password (min 8 characters)
4. Complete onboarding (DOB, sex, consent if EU region)
5. Home screen appears with connection indicator

---

## Deployment Checklist

### Before Release

- [ ] All 4 Supabase migrations applied
- [ ] Email confirmation configured appropriately (off for dev, on for prod)
- [ ] `hlth.env.json` has production Supabase URL and anon key
- [ ] Edge Function deployed: `supabase functions deploy health-insights`
- [ ] RLS policies verified in Supabase dashboard
- [ ] Privacy policy URLs in `GeoConfig` point to real pages
- [ ] `kCurrentPolicyVersion` in consent_service.dart matches current policy

### Production Environment

- [ ] Supabase project in Frankfurt (eu-central-1)
- [ ] Service role key secured (never in client code)
- [ ] Database backups enabled
- [ ] Auth rate limits configured
- [ ] Edge Function secrets configured

---

## Testing & QA

### Cloud Sync

| Test | Steps | Expected |
|------|-------|----------|
| Happy path | Connect band, wait for sync, check Supabase dashboard | `daily_metrics` rows appear |
| Offline queue | Airplane mode ON, sync band, airplane OFF | Outbox fills, then drains |
| Retry | Kill network mid-push | `attempts` increments, retries on next tick |
| Deduplication | Trigger sync twice quickly | No duplicate outbox entries |

### Connection Indicator

| Test | Steps | Expected |
|------|-------|----------|
| Online | Normal operation | Green dot |
| Offline | Toggle airplane mode | Amber dot |
| Auth expired | Invalidate token | Red dot |

### Geo Configuration

| Test | Steps | Expected |
|------|-------|----------|
| EU locale | Set device to de_DE, fresh install | Consent page appears in onboarding |
| US locale | Set device to en_US, fresh install | Consent page skipped |
| Override | Change region in settings | New region's rules apply immediately |

### Feature Gate

| Test | Steps | Expected |
|------|-------|----------|
| Free tier | No subscription row | Premium features locked |
| Premium tier | Insert subscription in Supabase, restart app | Premium features unlocked |
| Expired | Set `expires_at` to past date | Falls back to free tier |

### Auth Recovery

| Test | Steps | Expected |
|------|-------|----------|
| Refresh success | Normal token expiry | Auto-refreshed, no user impact |
| Refresh failure x3 | Simulate persistent 401 | Red dot, soft re-auth prompt |
| Recovery | Sign in again after failure | Counter resets, green dot |

---

## Decision Log

Key architectural decisions made during this build:

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Backend | Supabase over Firebase | ~10x cheaper at scale for health data; PostgreSQL is more flexible than Firestore for relational health metrics |
| Data residency | Frankfurt (eu-central-1) | Ryan's V1 sign-off; covers GDPR by default |
| Sync pattern | Outbox over direct push | Guarantees eventual delivery; survives offline/crashes |
| What syncs | Aggregated rollups only (V1) | Raw time-series stays local for privacy and cost; ~365 rows/yr/user vs ~500K raw samples |
| User ID | Map at push time, not migrate | Simpler V1; avoids risky bulk update across 14 local tables |
| Geo default | EU-strict fallback | Safest for unknown regions; avoids legal liability |
| Consent storage | Dual (local + cloud) | Local for instant checks; cloud for legal audit trail |
| Feature gate | Days + tier combined | Free features unlock over time; premium adds server-side compute |
| Subscription writes | service_role only | Prevents client-side subscription forgery |
| Auth recovery | Soft re-auth, not hard logout | Preserves local data; user just re-enters password |
| Retry strategy | Exponential backoff with jitter | Prevents thundering herd on reconnect |

---

## Changelog

### V1.0 — 2026-06-18

**Commit:** `c0a8da6`

**Added:**
- ConnectivityService: online/offline monitoring with DNS probe confirmation
- SupabaseConnectionMonitor: auth-aware connection health + retry utility
- ConnectionIndicator: green/amber/red dot widget in home screen app bar
- Cloud sync outbox pattern: local queue -> Supabase upsert on periodic tick
- CloudSyncOutbox Drift table (schema v3)
- SupabaseSyncRepository: PostgREST push for daily_metrics, baselines, devices, user_profiles
- GeoConfig: region presets for EU, US, Thailand, China, Other
- RegionDetector: locale-based region detection with user override
- ConsentService: consent grant/revoke with dual storage (local + Supabase)
- Consent page in onboarding flow (geo-aware, shown for GDPR/PDPA/PIPL regions)
- Router consent gate redirect
- Entitlement model (SubscriptionTier + Entitlement with expiration)
- EntitlementService: subscription fetch + offline cache
- FeatureGate tier extension: 5 premium gates (aiInsights, advancedSleepScoring, healthRiskPredictions, crossMetricCorrelations, trendAnalysis)
- Edge Function stub: health-insights (JWT + subscription validation)
- ServerInsightsService: Flutter client for Edge Function
- AuthRecovery: token refresh failure detection + soft re-auth
- Supabase migration 001: updated_at on daily_metrics + baselines
- Supabase migration 002: consent_records table + geo_region column
- Supabase migration 003: subscriptions table
- Architecture documentation

**Modified:**
- SyncService: wired cloud sync enqueue after band sync aggregation
- PeriodicSyncCoordinator: drains cloud outbox after each periodic tick
- FeatureGate: added tier field for premium gating
- DailyMetricsRepository: added getById()
- BaselineRepository: added getById()
- pubspec.yaml: added connectivity_plus dependency

**Dependencies:**
- Added: `connectivity_plus: ^6.1.0`

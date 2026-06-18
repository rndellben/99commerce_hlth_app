# HLTH Supabase Backend Architecture

> Built 2026-06-18. Covers cloud sync, geo-privacy, free/paid gating, and connection resilience.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Phase 1: Connection Infrastructure](#phase-1-connection-infrastructure)
4. [Phase 2: Cloud Sync (Outbox Pattern)](#phase-2-cloud-sync-outbox-pattern)
5. [Phase 3: Geo-Specific Configuration](#phase-3-geo-specific-configuration)
6. [Phase 4: Free vs Paid Feature Gating](#phase-4-free-vs-paid-feature-gating)
7. [Phase 5: Auth Recovery](#phase-5-auth-recovery)
8. [Supabase Migrations](#supabase-migrations)
9. [Edge Functions](#edge-functions)
10. [File Reference](#file-reference)
11. [Configuration](#configuration)
12. [Testing & Verification](#testing--verification)

---

## Overview

The HLTH app uses **Supabase** (Frankfurt, eu-central-1) as its backend. The architecture is **offline-first**: all health data is collected from the H59 band via BLE, stored locally in Drift SQLite, then synced to Supabase when connectivity is available.

**What syncs to the cloud (V1.0):**
- `daily_metrics` — 1 row per user per local day (~365/yr/user)
- `baselines` — rolling 14/30/90-day statistical baselines
- `devices` — paired band metadata
- `user_profiles` — user preferences and biometrics

**What stays local (V1.0):**
- Raw time-series: `hr_samples`, `hrv_samples`, `spo2_samples`, `bp_readings`, `stress_samples`
- `step_buckets`, `sleep_sessions`, `sleep_epochs`
- `sync_state` watermarks

**Supabase services used:**
| Service | Purpose |
|---------|---------|
| Auth | Email/password signup, JWT tokens, secure refresh |
| PostgREST | CRUD for all cloud tables via RLS |
| Edge Functions | Premium server-side compute (health insights) |
| Realtime | Reserved for V1.1 (capped at 2 events/sec) |

---

## Architecture Diagram

```
                          +------------------+
                          |   Supabase       |
                          |   (Frankfurt)    |
                          |                  |
                          |  +------------+  |
                          |  | Auth       |  |
                          |  +------------+  |
                          |  | PostgREST  |  |
                          |  | (RLS)      |  |
                          |  +------------+  |
                          |  | Edge Fns   |  |
                          |  +------------+  |
                          +--------+---------+
                                   |
                          HTTPS (JWT auth)
                                   |
+------------------------------------------------------------------+
|  Flutter App                                                      |
|                                                                   |
|  +---------------------+    +-------------------------------+     |
|  | ConnectivityService  |    | SupabaseConnectionMonitor     |    |
|  | (online/offline)     +--->| (ready? retry? health?)       |    |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  +---------------------+    +-------------------------------+     |
|  | BLE Band Sync       |    | Cloud Sync                    |     |
|  |                      |    |                               |     |
|  | BleService           |    | CloudSyncOutboxRepo (local)   |     |
|  |   -> SyncAdapters    |    |   -> SupabaseSyncRepo (push)  |     |
|  |   -> SyncService     +--->|   -> CloudSyncService (orch)  |     |
|  |   -> DailyAggregator |    |                               |     |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  +---------------------+    +-------------------------------+     |
|  | Geo Config           |    | Feature Gate                  |     |
|  | RegionDetector       |    | FeatureGate (days + tier)     |     |
|  | GeoConfig presets    |    | EntitlementService            |     |
|  | ConsentService       |    | ServerInsightsService         |     |
|  +---------------------+    +-------------------------------+     |
|                                                                   |
|  +---------------------+                                         |
|  | Auth Recovery        |                                         |
|  | Token refresh retry  |                                         |
|  | Soft re-auth flag    |                                         |
|  +---------------------+                                         |
+------------------------------------------------------------------+
```

---

## Phase 1: Connection Infrastructure

### ConnectivityService

**File:** `lib/core/services/connectivity_service.dart`

Monitors device network state using `connectivity_plus` with a DNS lookup confirmation.

| Provider | Type | Description |
|----------|------|-------------|
| `connectivityServiceProvider` | `Provider<ConnectivityService>` | Singleton service instance |
| `connectivityStateProvider` | `StreamProvider<ConnectivityStatus>` | Reactive online/offline stream |

**Behavior:**
- Listens to `connectivity_plus` radio events
- Debounces 500ms to avoid flapping
- Confirms reachability with `InternetAddress.lookup('dns.google')` (3s timeout)
- Emits `ConnectivityStatus.online` or `ConnectivityStatus.offline`

### SupabaseConnectionMonitor

**File:** `lib/core/services/supabase_connection_monitor.dart`

Combines network state with auth token validity.

| Provider | Type | Description |
|----------|------|-------------|
| `supabaseReadyProvider` | `Provider<bool>` | True when online AND authenticated |
| `connectionHealthProvider` | `Provider<ConnectionHealth>` | `connected` / `offline` / `authExpired` |

**Retry Utility:**
```dart
// Used by all Supabase calls. Exponential backoff: 200ms, 400ms, 800ms...
final result = await SupabaseConnectionMonitor.withRetry(() async {
  return await supabase.from('daily_metrics').upsert(data);
}, maxAttempts: 3);
```

### ConnectionIndicator Widget

**File:** `lib/ui/widgets/connection_indicator.dart`

Small colored dot in the home screen app bar:
- Green = cloud connected
- Amber = offline (local-only mode)
- Red = sign-in required

---

## Phase 2: Cloud Sync (Outbox Pattern)

### How It Works

```
Band Sync Complete
       |
       v
DailyAggregator.aggregateRecent()
       |
       v
CloudSyncService.enqueueRecentMetrics()   <-- Queues dirty rows
CloudSyncService.enqueueIdentity()        <-- Queues device + profile
       |
       v
[Outbox Table in local SQLite]            <-- Persists across app restarts
       |
       v
CloudSyncService.processOutbox()          <-- Runs on every periodic tick (~30min)
       |                                       and on every band connect event
       v
SupabaseSyncRepository.pushXxx()          <-- PostgREST upsert with retry
       |
       v
OutboxRepository.dequeue()                <-- Remove on success
```

### Outbox Table (Local Drift)

```
CloudSyncOutbox
  id             TEXT PK     -- UUID v4
  target_table   TEXT        -- 'daily_metrics', 'baselines', 'devices', 'user_profiles'
  record_id      TEXT        -- PK of the record to push
  created_at_utc INTEGER     -- Unix seconds
  attempts       INTEGER     -- Retry counter (default 0)
  last_attempt   INTEGER?    -- Last attempt timestamp
  last_error     TEXT?       -- Last failure message
```

**Schema version:** 3 (v2->v3 migration adds this table)

### Deduplication

`enqueue()` checks for an existing entry with the same `target_table` + `record_id` before inserting. Safe to call repeatedly.

### Failure Handling

- Each failed push increments `attempts` and records the error
- Entries exceeding 10 attempts are purged by `purgeStaleFailed()`
- Failures are non-fatal: band sync and local data are never affected

### User ID Bridging

All local data uses `userId = 'local-user-v1'`. The `SupabaseSyncRepository` substitutes the real Supabase `auth.uid()` when pushing to the cloud. This is a V1 decision; V2 may migrate all local rows to the auth UUID.

### Key Files

| File | Purpose |
|------|---------|
| `lib/core/repositories/cloud_sync_outbox_repository.dart` | Local outbox CRUD (enqueue, dequeue, retry, purge) |
| `lib/core/repositories/supabase_sync_repository.dart` | PostgREST push logic (4 upsert methods) |
| `lib/core/services/cloud_sync_service.dart` | Orchestrator (enqueue + processOutbox) |
| `lib/core/services/sync_service.dart` | Wiring point (calls cloud sync after band sync) |

---

## Phase 3: Geo-Specific Configuration

### Supported Regions

| Region | Regulation | Explicit Consent | Min Age | Retention | Right to Delete |
|--------|-----------|-----------------|---------|-----------|-----------------|
| EU | GDPR | Yes | 16 | 3 years | Yes |
| US | CCPA | No | 13 | 5 years | Yes |
| Thailand | PDPA | Yes | 13 | 3 years | Yes |
| China | PIPL | Yes | 14 | 2 years | Yes |
| Other | (EU-strict default) | Yes | 13 | 3 years | Yes |

### Region Detection

**File:** `lib/core/config/region_detector.dart`

Priority:
1. Explicit user override (stored in SharedPreferences)
2. Device locale country code (`Platform.localeName` -> ISO 3166-1 alpha-2)
3. Fallback: `GeoRegion.other` (EU-strict defaults — safest)

Coverage: 31 EU/EEA/UK country codes, 5 US territories, TH, CN.

### Consent System

**File:** `lib/core/services/consent_service.dart`

**Required consent types per region:**
- Regions with `requiresExplicitConsent = true`: `['data_processing', 'health_data']`
- All other regions: `['health_data']`

**Storage:**
- **Local:** SharedPreferences (`consent_{type}_granted`, `consent_{type}_version`)
- **Cloud:** `consent_records` table in Supabase (audit trail for legal compliance)

**Policy versioning:** Consent is tied to `kCurrentPolicyVersion` (currently `'1.0.0'`). When the privacy policy changes, bump this constant — users who consented to an older version will be re-prompted.

### Consent Flow

```
Onboarding Screen
  |
  +-- Welcome Page
  +-- Profile Page (DOB, sex, height, weight, units)
  +-- Cycle Page (if female)
  +-- Consent Page (if region requires explicit consent)  <-- NEW
  |     - Data processing consent checkbox
  |     - Health data consent checkbox
  |     - Shows regulation label (GDPR/PDPA/PIPL)
  |     - Shows data residency region
  +-- Disclaimer Page
  |
  v
Submit -> recordConsent() -> SharedPreferences + Supabase
```

### Router Consent Gate

In `lib/core/routing/router.dart`, after the profile gate:

```dart
if (geoConfig.requiresExplicitConsent) {
  if (!hasConsent && !atOnboarding && loc != '/privacy') {
    return '/onboarding';
  }
}
```

Routes `/onboarding` and `/privacy` are always reachable (so the user can grant consent or read the privacy policy).

### Supabase Schema

```sql
consent_records
  id              uuid PK
  user_id         uuid FK -> users(id) ON DELETE CASCADE
  consent_type    text       -- 'data_processing', 'health_data', 'analytics'
  granted         boolean
  granted_at      timestamptz
  revoked_at      timestamptz (nullable)
  policy_version  text       -- semver of the policy text
  geo_region      text       -- 'eu', 'us', 'th', 'cn', 'other'
  created_at      timestamptz

-- RLS: users can only read/insert/update their own records
-- Index: (user_id, consent_type)
```

---

## Phase 4: Free vs Paid Feature Gating

### On-Device (Free) Metrics

These run entirely on the device — no server needed, no subscription required.

| Metric | Source |
|--------|--------|
| Heart rate (resting, live, historical) | Band + local aggregator |
| SpO2 (overnight avg/min) | Band + local aggregator |
| Sleep (duration, stages, efficiency) | Band + local aggregator |
| Steps / distance / calories | Band direct |
| HRV (RMSSD, SDNN, PNN50) | Band + local HRV calculator |
| Stress score | Band-derived (pressure feature) |
| Blood pressure (band estimate) | Band sensor |
| Recovery score | Local baseline math (14-day) |
| Fall detection | Local accel state machine |
| Respiratory rate | Local signal processing |

### Server-Side (Premium) Features

These require the Supabase Edge Function and an active premium subscription.

| Feature | Why Server | Day Gate |
|---------|-----------|----------|
| AI health insights | LLM inference, cross-metric reasoning | None |
| Advanced sleep analysis | Multi-night pattern detection | 7 days |
| Health risk predictions | Population-level baselines | 30 days |
| Cross-metric correlations | Requires all metrics in one place | 14 days |
| Trend analysis (30/90 day) | Historical aggregation | 90 days |

### Subscription Model

**Supabase table:** `subscriptions`

```sql
subscriptions
  id          uuid PK
  user_id     uuid FK -> users(id)
  tier        text     -- 'free', 'premium'
  started_at  timestamptz
  expires_at  timestamptz (nullable)
  is_active   boolean
  provider    text     -- 'apple', 'google', 'stripe'
  provider_id text     -- external subscription ID
```

**RLS:** Users can only read their own subscription. Writes are restricted to `service_role` (server-side webhook from Apple/Google IAP).

### EntitlementService

**File:** `lib/core/services/entitlement_service.dart`

- Fetches active subscription from Supabase on app start
- Caches tier + expiry in SharedPreferences for offline access
- Re-fetches when auth state changes
- Returns `Entitlement` with `effectiveTier` (accounts for expiration)

### FeatureGate Integration

**File:** `lib/core/services/feature_gate.dart`

The existing `FeatureGate` class now has a `tier` field:

```dart
class FeatureGate {
  FeatureGate({
    required this.daysSinceFirstWear,
    this.baselineEstablished = const {},
    this.tier = SubscriptionTier.free,
  });

  // Existing day-based gates...
  bool get heartRate => true;           // Day 0, free
  bool get recoveryScore => days >= 14; // Day 14, free

  // New premium gates
  bool get aiInsights => _isPremium;
  bool get advancedSleepScoring => _isPremium && days >= 7;
  bool get healthRiskPredictions => _isPremium && days >= 30;
  bool get crossMetricCorrelations => _isPremium && days >= 14;
  bool get trendAnalysis => _isPremium && longTermTrends;
}
```

### Edge Function: health-insights

**File:** `supabase/functions/health-insights/index.ts`

**Request flow:**
1. Validate JWT from `Authorization` header
2. Check premium subscription (query `subscriptions` table)
3. Check expiration
4. Query `daily_metrics` (last 30 days) and `baselines`
5. Return structured insight payload

**Deploy:** `supabase functions deploy health-insights`

**Flutter client:** `lib/core/services/server_insights_service.dart`
- Calls `supabase.functions.invoke('health-insights')`
- Parses `InsightsResult` with typed `HealthInsight` objects
- Uses `withRetry` for resilience

---

## Phase 5: Auth Recovery

**File:** `lib/core/auth/auth_recovery.dart`

Handles token refresh failures gracefully without losing local data.

### Behavior

1. Listens to `onAuthStateChange` for `tokenRefreshed` / `signedOut` events
2. When a Supabase API call returns 401, call `onAuthError()`
3. First 3 failures: attempt `refreshSession()` manually
4. After 3 consecutive failures: set `needsReAuth = true`
5. Router can show a soft re-auth overlay (not a hard logout)
6. Successful refresh resets the failure counter

### Providers

| Provider | Type | Description |
|----------|------|-------------|
| `authRecoveryProvider` | `Provider<AuthRecovery>` | Singleton recovery monitor |
| `needsReAuthProvider` | `StreamProvider<bool>` | True when re-auth needed |

---

## Supabase Migrations

Apply in order to your Supabase project (SQL Editor or `supabase db push`):

| Migration | Purpose |
|-----------|---------|
| `20260617_000_identity.sql` | Base schema: users, user_profiles, devices, daily_metrics, baselines + RLS |
| `20260618_001_sync_tracking.sql` | Add `updated_at` to daily_metrics and baselines + triggers |
| `20260618_002_consent_geo.sql` | consent_records table + geo_region on user_profiles |
| `20260618_003_entitlements.sql` | subscriptions table for free/premium gating |

All tables use RLS scoped to `auth.uid() = user_id`. Delete policies are intentionally omitted — account deletion cascades from `auth.users`.

---

## Edge Functions

| Function | Path | Purpose |
|----------|------|---------|
| `health-insights` | `supabase/functions/health-insights/index.ts` | Premium health insights (stub — real ML is a future workstream) |

**Deploy:** `supabase functions deploy health-insights`
**Local test:** `supabase functions serve` then `curl` with Authorization header

---

## File Reference

### New Files Created

| File | Layer | Purpose |
|------|-------|---------|
| `lib/core/services/connectivity_service.dart` | Infrastructure | Online/offline detection |
| `lib/core/services/supabase_connection_monitor.dart` | Infrastructure | Auth-aware health + retry utility |
| `lib/ui/widgets/connection_indicator.dart` | UI | Green/amber/red status dot |
| `lib/core/repositories/cloud_sync_outbox_repository.dart` | Data | Local outbox CRUD |
| `lib/core/repositories/supabase_sync_repository.dart` | Data | PostgREST push (4 entity types) |
| `lib/core/services/cloud_sync_service.dart` | Service | Outbox orchestrator |
| `lib/core/config/geo_config.dart` | Config | Region presets (EU/US/TH/CN/other) |
| `lib/core/config/region_detector.dart` | Config | Locale-based region detection |
| `lib/core/services/consent_service.dart` | Service | Consent grant/revoke/check |
| `lib/core/models/entitlement.dart` | Model | SubscriptionTier + Entitlement |
| `lib/core/services/entitlement_service.dart` | Service | Subscription fetch + cache |
| `lib/core/services/server_insights_service.dart` | Service | Edge Function client |
| `lib/core/auth/auth_recovery.dart` | Auth | Token refresh failure recovery |
| `supabase/migrations/20260618_001_sync_tracking.sql` | Migration | updated_at triggers |
| `supabase/migrations/20260618_002_consent_geo.sql` | Migration | Consent + geo_region |
| `supabase/migrations/20260618_003_entitlements.sql` | Migration | Subscriptions table |
| `supabase/functions/health-insights/index.ts` | Edge Function | Premium insights stub |

### Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `connectivity_plus: ^6.1.0` |
| `lib/core/database/tables.dart` | Added `CloudSyncOutbox` table |
| `lib/core/database/app_database.dart` | Schema v3, registered outbox, migration |
| `lib/core/repositories/daily_metrics_repository.dart` | Added `getById()` |
| `lib/core/repositories/baseline_repository.dart` | Added `getById()` |
| `lib/core/services/sync_service.dart` | Wired cloud sync into SyncService + PeriodicSyncCoordinator |
| `lib/core/services/feature_gate.dart` | Added `tier` field + premium feature gates |
| `lib/features/home/home_screen.dart` | Added ConnectionIndicator to app bar |
| `lib/features/onboarding/onboarding_screen.dart` | Added geo-aware consent page |
| `lib/core/routing/router.dart` | Added consent gate redirect |

---

## Configuration

### Environment Variables

Create `hlth.env.json` (gitignored) from the example template:

```json
{
  "SUPABASE_URL": "https://cslejebgczfhocmgcnbg.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY_HERE",
  "FLAVOR": "dev"
}
```

Run with: `flutter run --dart-define-from-file=hlth.env.json`

### Supabase Project

- **Region:** Frankfurt (eu-central-1)
- **URL:** `https://cslejebgczfhocmgcnbg.supabase.co`
- **Auth:** Email/password with auto-refresh tokens
- **RLS:** All tables scoped to `auth.uid()`

---

## Testing & Verification

### Cloud Sync
1. Complete a band sync (connect band, wait for periodic tick or use debug screen)
2. Check Supabase dashboard: `daily_metrics` rows should appear for the authenticated user
3. Toggle airplane mode during sync — verify outbox accumulates locally
4. Re-enable network — verify outbox drains on next tick

### Offline Resilience
1. Airplane mode ON
2. Pair band, collect data, run sync — all data persists locally
3. Airplane mode OFF
4. Outbox processes automatically on next periodic tick (~30min) or band connect

### Geo Configuration
1. Change device locale to an EU country (e.g. de_DE)
2. Re-launch app — verify consent page appears in onboarding
3. Change to US locale — verify consent page is skipped
4. Override region in settings — verify override takes precedence

### Feature Gate
1. With no subscription: verify premium features (AI Insights, etc.) are locked
2. Insert a test subscription row in Supabase: `INSERT INTO subscriptions (user_id, tier, is_active) VALUES ('your-uuid', 'premium', true);`
3. Restart app — verify premium features unlock

### Connection Indicator
1. With network: green dot in home screen app bar
2. Airplane mode: amber dot
3. Invalidate auth token: red dot

### Auth Recovery
1. Normal operation: green indicator, syncs work
2. Simulate token expiry: auth recovery attempts refresh
3. After 3 failures: `needsReAuth` flag set, app can show soft re-auth prompt
4. User signs in again: counter resets, normal operation resumes

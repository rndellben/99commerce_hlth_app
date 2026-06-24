# Push-Notification Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use flutter-craft:flutter-executing to implement this plan task-by-task.

**Goal:** Build the on-device alert + notification foundation that the four Ryan-requested features (hypertension alert, irregular-R-R/AFib alert, sleep-apnea SpO2 alert, retention push) plug into — with strict, rate-limited firing and no false alarms.

**Architecture:** Matches the existing hlth_app layout (NOT generic Clean-Architecture folders): `core/database` (Drift tables + migration), `core/repositories` (data access), `core/services` (logic + Riverpod providers), wired through `PeriodicSyncCoordinator`. Riverpod for DI.

**Dependencies:**
```bash
flutter pub add flutter_local_notifications
```

---

## Key decision: local notifications, not server push (for V1)

Ryan was unsure whether to use Flutter-native local notifications or Supabase-driven push. **Recommendation: local notifications.** Rationale:

- All four triggers are **computed on-device** from data already synced into Drift (BP readings, R-R/ectopics, SpO2, last-sync time). No server needs to detect anything.
- The evaluation point already exists and **already runs in the background**: `PeriodicSyncCoordinator._onTick()` fires on the native sync tick (Android foreground service / iOS BG refresh).
- Offline-first: fires with no network. No FCM project, APNs certs, or device-token plumbing to stand up now.

**Seam for later:** the `NotificationService` interface is delivery-agnostic. When server-initiated pushes are needed (e.g. AI insights, marketing), add an FCM `RemoteNotificationService` behind the same interface — no change to the rules engine.

This plan builds the infra **plus one reference rule (retention)** to prove the pipe end-to-end. The other three rules are follow-on tasks (scoped at the end), because two of them have data prerequisites that aren't infra.

---

## Architecture overview

```
PeriodicSyncCoordinator._onTick()           [existing — add one call]
        │  (after band sync + cloud outbox)
        ▼
AlertEvaluator.evaluateAll(userId)           [new service]
        │  for each registered AlertRule:
        │    candidate = rule.evaluate(ctx)            → null = nothing to fire
        │    if candidate != null:
        │       last = notificationLog.lastFiredFor(type, dedupeKey)
        │       if (now - last) < rule.minInterval → SUPPRESS (rate-limit)
        │       else → NotificationService.show(...) + notificationLog.insert(...)
        ▼
NotificationService  ──►  flutter_local_notifications  ──►  OS notification
NotificationLogRepository ──► notification_log (Drift)   [dedup + rate-limit + history]
```

Rate-limiting and dedup live in `notification_log`, not in each rule — so "only once every 7 days" (Ryan's explicit ask) is enforced uniformly and survives app restarts.

---

## Data Layer

### Task 1: `notification_log` Drift table

**Layer:** Data (database)

**Files:**
- Modify: `lib/core/database/tables.dart`

**Implementation:** Mirror the existing `BatteryTelemetry` / `ExerciseSessions` table style in this file.

```dart
/// Log of every fired (and suppressed-decision) local notification.
/// Powers rate-limiting / dedup (Ryan: "only show once every 7 days") and
/// an in-app notification history. One row per *fired* notification.
class NotificationLog extends Table {
  TextColumn get id => text()();                       // uuid v4
  TextColumn get userId => text()();
  /// Stable rule id, e.g. 'hypertension' | 'afib' | 'sleep_apnea' | 'retention'.
  TextColumn get type => text()();
  /// Per-occurrence key for dedup, e.g. 'afib-2026-06-22'. Rate-limit is
  /// checked per (userId, type) using the most recent firedAtUtc.
  TextColumn get dedupeKey => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  /// JSON string for tap-routing payload (nullable).
  TextColumn get payload => text().nullable()();
  /// 'alert' (high importance) | 'retention' (default importance).
  TextColumn get channel => text()();
  IntColumn get firedAtUtcSec => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Verification:**
```bash
flutter analyze lib/core/database/tables.dart
# Expected: No issues found! (the generated .g.dart updates in Task 3)
```

---

### Task 2: Register table + bump schema to v6

**Layer:** Data (database)

**Files:**
- Modify: `lib/core/database/app_database.dart`

**Implementation:** Add `NotificationLog` to the `@DriftDatabase(tables: [...])` list, bump `schemaVersion` 5 → 6, and add the migration step (mirror the `from < 5` block):

```dart
int get schemaVersion => 6;
// ...inside onUpgrade:
if (from < 6) {
  await m.createTable(notificationLog);
}
```

**Verification:**
```bash
cd hlth_app && dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/core/database/
# Expected: No issues found!
```

---

### Task 3: `NotificationLogRepository`

**Layer:** Data (repository)

**Files:**
- Create: `lib/core/repositories/notification_log_repository.dart`
- Test: `test/notification_log_repository_test.dart`

**Implementation:** Follow the existing repository style (constructor takes `AppDatabase`, Provider at bottom; import `app_database.dart as db` to avoid the generated row-class name collision, per `exercise_session_repository.dart`).

```dart
class NotificationLogRepository {
  NotificationLogRepository(this._db);
  final db.AppDatabase _db;

  Future<void> insert({
    required String id,
    required String userId,
    required String type,
    required String dedupeKey,
    required String title,
    required String body,
    String? payload,
    required String channel,
    required DateTime firedAtUtc,
  }) async { /* into(_db.notificationLog).insert(...) */ }

  /// Most recent fire time for (userId, type), or null if never fired.
  /// Drives the per-rule minInterval rate-limit.
  Future<DateTime?> lastFiredFor({
    required String userId,
    required String type,
  }) async { /* select ... orderBy firedAtUtcSec desc, limit 1 */ }

  /// Recent history for an in-app notifications list (newest first).
  Future<List<db.NotificationLogData>> recent({
    required String userId,
    int limit = 50,
  }) async { /* ... */ }
}

final notificationLogRepositoryProvider =
    Provider<NotificationLogRepository>((ref) =>
        NotificationLogRepository(ref.watch(appDatabaseProvider)));
```

**Test (Priority 1):** in-memory `AppDatabase`, assert `lastFiredFor` returns the most recent row and null when empty.

**Verification:**
```bash
flutter test test/notification_log_repository_test.dart
flutter analyze lib/core/repositories/notification_log_repository.dart
```

---

## Service Layer

### Task 4: `NotificationService` (delivery wrapper)

**Layer:** Service

**Files:**
- Create: `lib/core/services/notification_service.dart`

**Implementation:** Wrap `flutter_local_notifications`. Two Android channels (`alert` = high importance, `retention` = default). iOS Darwin permissions. Delivery-agnostic interface so an FCM impl can slot in later.

```dart
enum AlertChannel { alert, retention }

class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    // AndroidInitializationSettings('@mipmap/ic_launcher'),
    // DarwinInitializationSettings(requestAlert/Badge/Sound: false — ask later),
    // create the two Android channels.
  }

  /// Ask once (Android 13+ POST_NOTIFICATIONS / iOS prompt). Returns granted.
  Future<bool> requestPermission() async { /* ... */ }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required AlertChannel channel,
    String? payload,
  }) async { /* _plugin.show(... channel-specific NotificationDetails ...) */ }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
```

**Verification:**
```bash
flutter analyze lib/core/services/notification_service.dart
```

---

### Task 5: `AlertRule` contract + `AlertEvaluator`

**Layer:** Service

**Files:**
- Create: `lib/core/services/alerts/alert_rule.dart`
- Create: `lib/core/services/alerts/alert_evaluator.dart`
- Test: `test/alert_evaluator_test.dart`

**Implementation:**

```dart
// alert_rule.dart
class AlertContext {
  const AlertContext({required this.userId, required this.now});
  final String userId;
  final DateTime now;
}

class AlertCandidate {
  const AlertCandidate({
    required this.dedupeKey,
    required this.title,
    required this.body,
    required this.channel,
    this.payload,
  });
  final String dedupeKey;
  final String title;
  final String body;
  final AlertChannel channel;
  final Map<String, dynamic>? payload;
}

abstract class AlertRule {
  String get type;            // stable id, also the rate-limit key
  Duration get minInterval;   // Ryan: e.g. const Duration(days: 7)
  /// Return a candidate to fire, or null if nothing should fire this pass.
  /// Rules must be conservative — null when uncertain (no false alarms).
  Future<AlertCandidate?> evaluate(AlertContext ctx);
}
```

```dart
// alert_evaluator.dart
class AlertFireResult {
  const AlertFireResult({required this.type, required this.fired, this.reason});
  final String type;
  final bool fired;
  final String? reason; // 'fired' | 'no-candidate' | 'rate-limited' | 'error'
}

class AlertEvaluator {
  AlertEvaluator({
    required this.rules,
    required this.log,
    required this.notifications,
  });
  final List<AlertRule> rules;
  final NotificationLogRepository log;
  final NotificationService notifications;

  Future<List<AlertFireResult>> evaluateAll({
    required String userId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now().toUtc();
    final results = <AlertFireResult>[];
    for (final rule in rules) {
      try {
        final c = await rule.evaluate(AlertContext(userId: userId, now: ts));
        if (c == null) {
          results.add(AlertFireResult(type: rule.type, fired: false, reason: 'no-candidate'));
          continue;
        }
        final last = await log.lastFiredFor(userId: userId, type: rule.type);
        if (last != null && ts.difference(last) < rule.minInterval) {
          results.add(AlertFireResult(type: rule.type, fired: false, reason: 'rate-limited'));
          continue;
        }
        await notifications.show(
          id: rule.type.hashCode & 0x7fffffff,
          title: c.title, body: c.body, channel: c.channel,
          payload: c.payload == null ? null : jsonEncode(c.payload),
        );
        await log.insert(
          id: /* uuid */, userId: userId, type: rule.type,
          dedupeKey: c.dedupeKey, title: c.title, body: c.body,
          payload: c.payload == null ? null : jsonEncode(c.payload),
          channel: c.channel.name, firedAtUtc: ts,
        );
        results.add(AlertFireResult(type: rule.type, fired: true, reason: 'fired'));
      } catch (e) {
        results.add(AlertFireResult(type: rule.type, fired: false, reason: 'error'));
      }
    }
    return results;
  }
}

final alertEvaluatorProvider = Provider<AlertEvaluator>((ref) {
  return AlertEvaluator(
    rules: [ ref.watch(retentionRuleProvider) ], // grows as rules are added
    log: ref.watch(notificationLogRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
```

**Test (Priority 2):** fake `NotificationService` (records `show` calls) + in-memory log + a fake rule.
- candidate + never-fired → fires + logs once.
- second `evaluateAll` within `minInterval` → suppressed (`rate-limited`), no second `show`.
- after `minInterval` (advance `now`) → fires again.
- rule returns null → `no-candidate`, no `show`.

**Verification:**
```bash
flutter test test/alert_evaluator_test.dart
```

---

### Task 6: Reference rule — `RetentionRule`

**Layer:** Service (proves the pipe; also ships Ryan's retention push)

**Files:**
- Create: `lib/core/services/alerts/retention_rule.dart`

**Implementation:** Purely on-device, no blocked deps. Fires when the band hasn't synced in N days (reads the existing last-sync state used by `SyncStateRepository` / `sync_state`).

```dart
class RetentionRule implements AlertRule {
  RetentionRule({required this.syncStateRepo, this.staleAfter = const Duration(days: 3)});
  final SyncStateRepository syncStateRepo;
  final Duration staleAfter;

  @override
  String get type => 'retention';
  @override
  Duration get minInterval => const Duration(days: 3); // don't nag daily

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final lastSync = await syncStateRepo.lastSuccessfulSyncUtc(ctx.userId);
    if (lastSync == null) return null;
    if (ctx.now.difference(lastSync) < staleAfter) return null;
    return AlertCandidate(
      dedupeKey: 'retention',
      title: 'Sync your HLTH band',
      body: 'It’s been a few days — open the app to back up your health data.',
      channel: AlertChannel.retention,
    );
  }
}

final retentionRuleProvider = Provider<RetentionRule>((ref) =>
    RetentionRule(syncStateRepo: ref.watch(syncStateRepositoryProvider)));
```

> Implementer note: confirm the exact last-sync accessor on `SyncStateRepository`; adapt the method name if it differs.

**Verification:**
```bash
flutter analyze lib/core/services/alerts/
```

---

## Integration & Wiring

### Task 7: Init notifications at app boot + permission UX

**Layer:** Integration

**Files:**
- Modify: `lib/main.dart` (or the bootstrap that runs before `runApp`)
- Modify: `lib/app.dart` (request permission once after first frame, post-onboarding)

**Implementation:** `await ref.read(notificationServiceProvider).init()` during bootstrap; request permission at a sensible moment (after sign-in/onboarding, not cold-start). Gate the prompt behind a `shared_preferences` "asked once" flag.

**Verification:**
```bash
flutter analyze lib/main.dart lib/app.dart
```

---

### Task 8: Evaluate alerts on the sync tick

**Layer:** Integration

**Files:**
- Modify: `lib/core/services/sync_service.dart` (`PeriodicSyncCoordinator`)

**Implementation:** Add `AlertEvaluator` to the coordinator's constructor + `periodicSyncCoordinatorProvider`. In `_onTick()`, after the cloud-outbox drain, call:

```dart
try {
  await alertEvaluator.evaluateAll(userId: ActiveSession.defaultUserId);
} catch (_) { /* non-fatal — never kill the tick */ }
```

Mirror the existing non-fatal `try/catch` style already used for the cloud-outbox step.

**Verification:**
```bash
flutter analyze lib/core/services/sync_service.dart
flutter test   # full suite — confirm coordinator tests still pass
```

---

### Task 9: Android + iOS platform config

**Layer:** Integration

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS` permission (Android 13+); `flutter_local_notifications` receivers per its README.
- Modify: `android/app/build.gradle` — confirm `minSdk` / `desugar` if the plugin requires it.
- Modify: `ios/Runner/AppDelegate.swift` — register for local notifications.
- Modify: `ios/Runner/Info.plist` — background modes already present for BLE; add notification usage if required.

**Verification:**
```bash
flutter build apk --debug      # Android compiles with new permission/receivers
flutter build ios --no-codesign --debug   # iOS compiles
```

---

## Out of scope (follow-on rules — each a small `AlertRule` on this infra)

These are **not** in this plan; they slot in as one rule file + one line in `alertEvaluatorProvider` each:

1. **Irregular-R-R / AFib alert** — cheapest next; reads the cleaned R-R + ectopic data we already produce. Conservative thresholds; `minInterval` 7d.
2. **Sleep-apnea SpO2 alert** — in-app card + notification; reads SpO2 samples; build guide exists (`sleep-apnea-detection-build-guide.md`). **Prerequisite:** confirm the SpO2 interval stream is exposed for the H59 MAC.
3. **Hypertension alert** — **prerequisite that isn't infra:** there is currently **no BP baseline** (baselines cover HR/HRV/SpO2/sleep/steps/respRate, not sbp/dbp). Needs `sbp`/`dbp` added to `BaselineMetric` + `baseline_service` mapping, or an ad-hoc 7-day BP average from `bp_readings`. Also note baselines are 14/30/90-day; Ryan said "7-day," so add a 7-day window or use 14-day.

---

## Test summary

| Test | Priority | Asserts |
|------|----------|---------|
| `notification_log_repository_test.dart` | 1 | insert + `lastFiredFor` (most recent / null) |
| `alert_evaluator_test.dart` | 2 | fires once, rate-limits within `minInterval`, refires after, null candidate = no fire |

Widget tests: none required for infra.

---

## Verification (whole feature)

```bash
cd hlth_app
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyzer clean; all tests pass (the one pre-existing `widget_test.dart` failure — bare `ProviderScope` can't init `periodicSyncCoordinatorProvider` — is unrelated).

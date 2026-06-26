# Cardio Load Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use flutter-craft:flutter-executing (or flutter-subagent-dev) to implement this plan task-by-task.

**Goal:** Ship Ryan's delivered Cardio Load (Vascular Load) score by feeding his verbatim engine the per-night aggregates it needs, reconstructed from our stored samples.

**Architecture:** This repo's actual conventions — Riverpod + Drift + repositories + a vendored pure-Dart engine. (Mirrors exactly how Recovery/Stability was integrated: vendored engine in `core/scoring`, adapter service in `core/services`, persisted via the `scores` table.)

**Source of truth (do NOT rewrite):**
- Engine: `Transcript & Summary Calls/vascular_load (1).dart` — vendored verbatim. `reduceSession` and `computeVascularLoad` are untouched.
- Schema: `Transcript & Summary Calls/NIGHTLY_RECORD_SCHEMA.md`.
- UI spec: `Screen specs/09-cardio-load.md`.

**Dependencies:** none new.

---

## The core problem this plan solves

Ryan's `reduceSession` takes **per-epoch** `SleepEpochs` (equal-length lists of `hr`, `rmssd`, `stage`, `motion`, `stress`). Our `sleep_epochs` table stores **stage + duration only** — no per-epoch HR/RMSSD/stress. So the integration is two pieces:

1. **Reconstruct `SleepEpochs`** for a session by bucketing the timestamped samples we *do* keep (`hr_samples`, `hrv_samples`, `stress_samples`) onto a 1-minute grid laid over the session, with stage taken from `sleep_epochs`. This is exactly the device-glue Ryan left to us (`loadStoredSleepEpochs` in his integration notes).
2. **Persist the reduced `NightlyRecord`** in a new table. This is mandatory, not optional: the retention sweep deletes raw `hr/hrv/stress` samples after a retention window, so we cannot re-reduce old nights. Ryan's schema is explicit — "the device stores a rolling list of NightlyRecord." The score reads tonight + previous 3 valid nights against a 14-night baseline, so those reduced records must outlive the raw samples.

**Known limitation to document, not solve:** we have no per-epoch motion signal. `motion` is set `false` for every epoch — the band's own staging already drops gross movement into `wake` epochs, which `reduceSession` excludes via the asleep mask. Flag this in code + to Ryan; it's a faithful approximation given the hardware, not a silent shortcut.

---

## Domain / Engine Layer

### Task 1: Vendor the engine verbatim

**Layer:** Domain (vendored)

**Files:**
- Create: `lib/core/scoring/vascular_load.dart`

**Implementation:**
Copy `Transcript & Summary Calls/vascular_load (1).dart` byte-for-byte into the target path. Add ONLY a lint-ignore header at the very top (same treatment as `recovery_stability.dart`), no logic change:

```dart
// Vendored verbatim from Ryan's vascular_load.dart (2026-06-23 delivery).
// Source of truth — do NOT edit logic; only this ignore header is added.
// ignore_for_file: unused_element, prefer_null_aware_operators
```

Exposes: `SleepStage` (the engine's own enum: deep/light/rem/wake), `SleepEpochs`, `VascularLoadConfig`, `NightlyRecord`, `reduceSession`, `VlStatus`, `VascularLoadResult`, `computeVascularLoad`.

**Verification:**
```bash
flutter analyze lib/core/scoring/vascular_load.dart
# Expected: No issues found!
```

**Commit:** `feat(cardio): vendor Ryan's vascular_load engine verbatim`

---

### Task 2: Add `cardioLoad` to the ScoreType enum

**Layer:** Domain

**Files:**
- Modify: `lib/core/database/enums.dart`

**Implementation:**
Append a new value AFTER `recovery` (intEnum maps by index; appending is migration-safe, never reorder):

```dart
enum ScoreType {
  recovery,             // 0
  cardioLoad,           // 1 — Vascular Load (Engine A), one per sleep
}
```

**Verification:** `flutter analyze lib/core/database/enums.dart`

**Commit:** `feat(cardio): add cardioLoad ScoreType`

---

## Data Layer

### Task 3: `nightly_records` table

**Layer:** Data

**Files:**
- Modify: `lib/core/database/tables.dart`

**Implementation:** Mirrors `NIGHTLY_RECORD_SCHEMA.md` §1. One row per (user, sleep date).

```dart
/// Ryan's Vascular Load NightlyRecord (NIGHTLY_RECORD_SCHEMA.md §1) —
/// the tiny per-session struct the score reads. Persisted because the
/// retention sweep deletes the raw hr/hrv/stress samples it's reduced
/// from, so old nights can't be re-reduced. `localDate` is the sleep
/// (wake) date as YYYY-MM-DD text, same convention as daily_metrics.
class NightlyRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get localDate => text()();        // YYYY-MM-DD (wake date)
  RealColumn get hrP5 => real().nullable()();
  RealColumn get rmssdMedian => real().nullable()();
  RealColumn get stressMean => real().nullable()();
  RealColumn get coverage => real().withDefault(const Constant(0))();
  BoolColumn get valid => boolean().withDefault(const Constant(false))();
  IntColumn get computedAtUtc => integer()();
  TextColumn get algorithmVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Verification:** part of Task 4's codegen run.

**Commit:** `feat(cardio): add nightly_records table`

---

### Task 4: Register table + schema migration v8 → v9

**Layer:** Data

**Files:**
- Modify: `lib/core/database/app_database.dart`

**Implementation:**
1. Add `NightlyRecords` to the `@DriftDatabase(tables: [...])` list.
2. Bump `int get schemaVersion => 9;`
3. In the migration strategy, add:

```dart
if (from < 9) {
  await m.createTable(nightlyRecords);
  await customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_nightly_records_user_date '
    'ON nightly_records(user_id, local_date)',
  );
}
```
4. Add the same index to `_createIndices` (fresh-install path).

Then run codegen:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Verification:**
```bash
flutter analyze lib/core/database/
# Expected: No issues found!
```

**Commit:** `feat(cardio): register nightly_records, migrate schema v9`

---

### Task 5: `NightlyRecordRow` domain model

**Layer:** Data

**Files:**
- Create: `lib/core/models/nightly_record_row.dart`

> Naming: the engine already owns `NightlyRecord` (the compute struct). This is the *persisted* row; keep them distinct to avoid import clashes. The repository converts between them.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'nightly_record_row.freezed.dart';

/// Persisted form of Ryan's engine `NightlyRecord` (NIGHTLY_RECORD_SCHEMA.md).
@freezed
class NightlyRecordRow with _$NightlyRecordRow {
  const factory NightlyRecordRow({
    required String id,
    required String userId,
    required DateTime localDate,
    double? hrP5,
    double? rmssdMedian,
    double? stressMean,
    required double coverage,
    required bool valid,
    required DateTime computedAt,
    required String algorithmVersion,
  }) = _NightlyRecordRow;
}
```
Run `build_runner` again after creating.

**Verification:** `flutter analyze lib/core/models/nightly_record_row.dart`

**Commit:** `feat(cardio): add NightlyRecordRow model`

---

### Task 6: `NightlyRecordRepository`

**Layer:** Data

**Files:**
- Create: `lib/core/repositories/nightly_record_repository.dart`

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/nightly_record_row.dart';

abstract class NightlyRecordRepository {
  /// Upsert keyed on (userId, localDate) — re-reducing a night overwrites.
  Future<void> upsert(NightlyRecordRow row);

  /// Records with localDate strictly BEFORE [beforeDate], oldest first
  /// (most recent LAST — the order computeVascularLoad expects for history).
  Future<List<NightlyRecordRow>> getHistoryBefore({
    required String userId,
    required DateTime beforeDate,
    int limit = 30,
  });

  Future<NightlyRecordRow?> getForDate({
    required String userId,
    required DateTime localDate,
  });
}

class NightlyRecordRepositoryImpl implements NightlyRecordRepository {
  NightlyRecordRepositoryImpl(this._db);
  final db.AppDatabase _db;

  String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);
  int _toSec(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  String _idFor(String userId, DateTime localDate) =>
      '$userId:${_dateOnly(localDate)}';

  NightlyRecordRow _toDomain(db.NightlyRecord r) => NightlyRecordRow(
        id: r.id,
        userId: r.userId,
        localDate: DateTime.parse(r.localDate),
        hrP5: r.hrP5,
        rmssdMedian: r.rmssdMedian,
        stressMean: r.stressMean,
        coverage: r.coverage,
        valid: r.valid,
        computedAt: _toDt(r.computedAtUtc),
        algorithmVersion: r.algorithmVersion,
      );

  @override
  Future<void> upsert(NightlyRecordRow row) async {
    await _db.into(_db.nightlyRecords).insertOnConflictUpdate(
          db.NightlyRecordsCompanion.insert(
            id: _idFor(row.userId, row.localDate),
            userId: row.userId,
            localDate: _dateOnly(row.localDate),
            hrP5: Value(row.hrP5),
            rmssdMedian: Value(row.rmssdMedian),
            stressMean: Value(row.stressMean),
            coverage: Value(row.coverage),
            valid: Value(row.valid),
            computedAtUtc: _toSec(row.computedAt),
            algorithmVersion: row.algorithmVersion,
          ),
        );
  }

  @override
  Future<List<NightlyRecordRow>> getHistoryBefore({
    required String userId,
    required DateTime beforeDate,
    int limit = 30,
  }) async {
    final rows = await (_db.select(_db.nightlyRecords)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.isSmallerThanValue(_dateOnly(beforeDate)))
          ..orderBy([(t) => OrderingTerm.asc(t.localDate)])) // oldest first
        .get();
    final mapped = rows.map(_toDomain).toList();
    // Keep the most recent `limit` (history window), preserving asc order.
    return mapped.length > limit
        ? mapped.sublist(mapped.length - limit)
        : mapped;
  }

  @override
  Future<NightlyRecordRow?> getForDate({
    required String userId,
    required DateTime localDate,
  }) async {
    final r = await (_db.select(_db.nightlyRecords)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.equals(_dateOnly(localDate))))
        .getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }
}

final nightlyRecordRepositoryProvider =
    Provider<NightlyRecordRepository>((ref) {
  return NightlyRecordRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
```

**Verification:** `flutter analyze lib/core/repositories/nightly_record_repository.dart`

**Commit:** `feat(cardio): add NightlyRecordRepository`

---

### Task 7: `SleepEpochs` reconstruction adapter (the heart of the integration)

**Layer:** Data (adapter)

**Files:**
- Create: `lib/core/scoring/sleep_epochs_builder.dart`
- Test: `test/sleep_epochs_builder_test.dart`

Builds the engine's `SleepEpochs` from a session's stage timeline + timestamped samples. Pure + static so it's unit-testable with no DB.

```dart
import 'package:hlth_app/core/database/enums.dart' as dbenums;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart' as vl;

/// Reconstructs the engine's per-epoch [vl.SleepEpochs] for one session.
///
/// We lay a 1-minute grid over [start, end). Each timestamped sample is
/// bucketed into the minute it falls in (mean if several land together),
/// every other epoch is NaN — so `reduceSession`'s `.isFinite` checks see
/// exactly the real samples, never fabricated fill. Stage per epoch comes
/// from the sleep_epochs spans. `motion` is false for every epoch: we have
/// no per-epoch motion signal, and the band's staging already routes gross
/// movement into `wake` (which the asleep mask drops). Documented limitation.
class SleepEpochsBuilder {
  static vl.SleepEpochs build({
    required DateTime start,
    required DateTime end,
    required List<SleepEpoch> stages,
    required List<HrSample> hr,
    required List<HrvSample> hrv,
    required List<StressSample> stress,
  }) {
    final totalMin = end.difference(start).inMinutes;
    final n = totalMin <= 0 ? 0 : totalMin;

    final hrOut = List<double>.filled(n, double.nan);
    final rmssdOut = List<double>.filled(n, double.nan);
    final stressOut = List<double>.filled(n, double.nan);
    final stageOut =
        List<vl.SleepStage>.filled(n, vl.SleepStage.wake);
    final motionOut = List<bool>.filled(n, false);

    int idxFor(DateTime t) => t.difference(start).inMinutes;

    // Stage: paint each epoch span onto the grid.
    for (final e in stages) {
      final from = idxFor(e.startedAt);
      final to = idxFor(e.startedAt.add(Duration(minutes: e.durationMin)));
      final s = _mapStage(e.stage);
      for (var i = from; i < to && i < n; i++) {
        if (i >= 0) stageOut[i] = s;
      }
    }

    // Samples: bucket-mean into the grid.
    _bucketMean(hr.map((s) => (s.capturedAt, s.bpm.toDouble())), start, n, hrOut);
    _bucketMean(
        hrv.map((s) => (s.capturedAt, s.rmssdMs)), start, n, rmssdOut);
    _bucketMean(
        stress.map((s) => (s.capturedAt, s.stressScore.toDouble())),
        start, n, stressOut);

    return vl.SleepEpochs(
      hr: hrOut,
      rmssd: rmssdOut,
      stage: stageOut,
      motion: motionOut,
      stress: stressOut,
      epochMinutes: 1.0,
    );
  }

  static void _bucketMean(
    Iterable<(DateTime, double)> samples,
    DateTime start,
    int n,
    List<double> out,
  ) {
    final sums = List<double>.filled(n, 0);
    final counts = List<int>.filled(n, 0);
    for (final (t, v) in samples) {
      if (!v.isFinite) continue;
      final i = t.difference(start).inMinutes;
      if (i < 0 || i >= n) continue;
      sums[i] += v;
      counts[i] += 1;
    }
    for (var i = 0; i < n; i++) {
      if (counts[i] > 0) out[i] = sums[i] / counts[i];
    }
  }

  static vl.SleepStage _mapStage(dbenums.SleepStage s) {
    switch (s) {
      case dbenums.SleepStage.deep:
        return vl.SleepStage.deep;
      case dbenums.SleepStage.light:
        return vl.SleepStage.light;
      case dbenums.SleepStage.rem:
        return vl.SleepStage.rem;
      default: // awake, noSleep, unweared → treated as wake (asleep mask drops)
        return vl.SleepStage.wake;
    }
  }
}
```

**Test (Priority 1 — pure logic):**
```dart
// test/sleep_epochs_builder_test.dart
// - bucketing: a sample at 02:05 lands in epoch index 5, others NaN
// - stage painting: an epoch span [02:00,02:30) deep → epochs 0..29 deep
// - awake/noSleep/unweared all map to vl.SleepStage.wake
// - reduceSession over the built epochs yields finite hrP5/rmssdMedian
//   when ≥10 HR / ≥5 RMSSD samples fall in asleep (deep) epochs, NaN otherwise
```

**Verification:** `flutter test test/sleep_epochs_builder_test.dart`

**Commit:** `feat(cardio): reconstruct SleepEpochs from stored samples`

---

## Service Layer

### Task 8: `CardioLoadService` (adapter that drives Ryan's engine)

**Layer:** Service

**Files:**
- Create: `lib/core/services/cardio_load_service.dart`

Follows Ryan's integration notes (§DAILY FLOW) and mirrors `RecoveryScoreService`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/nightly_record_row.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/nightly_record_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/core/scoring/sleep_epochs_builder.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart' as vl;
import 'package:uuid/uuid.dart';

/// Computes Ryan's Vascular Load (Cardio Load) on the end-of-sleep trigger.
/// Reduces the most recent night to a NightlyRecord, persists it, then runs
/// `computeVascularLoad` over the rolling history and stores a Score.
class CardioLoadService {
  CardioLoadService({
    required this.sleepRepo,
    required this.hrRepo,
    required this.hrvRepo,
    required this.stressRepo,
    required this.nightlyRepo,
    required this.scoreRepo,
  });

  final SleepRepository sleepRepo;
  final HrRepository hrRepo;
  final HrvRepository hrvRepo;
  final StressRepository stressRepo;
  final NightlyRecordRepository nightlyRepo;
  final ScoreRepository scoreRepo;

  static const _uuid = Uuid();
  static const _algorithmVersion = 'vascular-load-engineA-v1';

  /// Returns the engine result when a night was reduced (even if calibrating/
  /// no-score), or null if there was no night session to reduce.
  Future<vl.VascularLoadResult?> computeForLatestNight({
    required String userId,
  }) async {
    // 1. Most recent night session = tonight's trigger.
    final session = await sleepRepo.watchMostRecentNight(userId).first;
    if (session == null) return null;

    final wakeLocal = session.endedAt.toLocal();
    final wakeDate = DateTime(wakeLocal.year, wakeLocal.month, wakeLocal.day);

    // 2. Pull the night's stored samples + stage timeline.
    final epochs = await sleepRepo.getEpochsForSession(session.id);
    final hr = await hrRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);
    final hrv = await hrvRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);
    final stress = await stressRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);

    // 3. Reconstruct per-epoch input → reduce to tonight's NightlyRecord.
    final sleepEpochs = SleepEpochsBuilder.build(
      start: session.startedAt,
      end: session.endedAt,
      stages: epochs,
      hr: hr,
      hrv: hrv,
      stress: stress,
    );
    final dateStr = wakeDate.toIso8601String().substring(0, 10);
    final tonight = vl.reduceSession(dateStr, sleepEpochs);

    // 4. Load history (records BEFORE tonight), compute banked valid count.
    final historyRows = await nightlyRepo.getHistoryBefore(
        userId: userId, beforeDate: wakeDate);
    final history = historyRows.map(_toEngine).toList();
    final banked = history.where((r) => r.valid).length;

    // 5. Run the engine verbatim.
    final result = vl.computeVascularLoad(
      history: history,
      tonight: tonight,
      bankedValidCount: banked,
    );

    // 6. Persist tonight's record AFTER computing (becomes history).
    await nightlyRepo.upsert(NightlyRecordRow(
      id: '',
      userId: userId,
      localDate: wakeDate,
      hrP5: tonight.hrP5.isFinite ? tonight.hrP5 : null,
      rmssdMedian: tonight.rmssdMedian.isFinite ? tonight.rmssdMedian : null,
      stressMean: tonight.stressMean.isFinite ? tonight.stressMean : null,
      coverage: tonight.coverage,
      valid: tonight.valid,
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    ));

    // 7. Persist the Score only when one was produced.
    if (result.produced && result.score != null) {
      await scoreRepo.upsert(Score(
        id: ScoreRepository.idFor(userId, ScoreType.cardioLoad, wakeDate),
        userId: userId,
        scoreType: ScoreType.cardioLoad,
        computedForDate: wakeDate,
        score: result.score!,
        label: result.label,
        provisional: false,
        components: result.components,
        computedAt: DateTime.now().toUtc(),
        algorithmVersion: _algorithmVersion,
      ));
    }
    return result;
  }

  vl.NightlyRecord _toEngine(NightlyRecordRow r) => vl.NightlyRecord(
        date: r.localDate.toIso8601String().substring(0, 10),
        hrP5: r.hrP5 ?? double.nan,
        rmssdMedian: r.rmssdMedian ?? double.nan,
        stressMean: r.stressMean ?? double.nan,
        coverage: r.coverage,
        valid: r.valid,
      );
}

final cardioLoadServiceProvider = Provider<CardioLoadService>((ref) {
  return CardioLoadService(
    sleepRepo: ref.watch(sleepRepositoryProvider),
    hrRepo: ref.watch(hrRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    stressRepo: ref.watch(stressRepositoryProvider),
    nightlyRepo: ref.watch(nightlyRecordRepositoryProvider),
    scoreRepo: ref.watch(scoreRepositoryProvider),
  );
});
```

> Confirm against the actual `Score` model / `ScoreRepository.idFor` / `watchMostRecentNight` signatures during execution; adjust field names if they differ. (These were defined in the Recovery work.)

**Verification:** `flutter analyze lib/core/services/cardio_load_service.dart`

**Commit:** `feat(cardio): add CardioLoadService driving the vendored engine`

---

### Task 9: Wire into the sync sweep

**Layer:** Integration

**Files:**
- Modify: `lib/core/services/sync_service.dart`

In `SyncService.syncAll`, right after the existing Recovery block (post-aggregate), add a Cardio Load trigger — non-fatal, mirrors Recovery:

```dart
if (aggregated) {
  try {
    await cardioLoad.computeForLatestNight(userId: userId);
  } catch (_) {}
}
```
Add `CardioLoadService cardioLoad` as a constructor dependency + wire it in `syncServiceProvider` (alongside `recoveryScore`).

**Verification:** `flutter analyze lib/core/services/sync_service.dart`

**Commit:** `feat(cardio): trigger Cardio Load on the post-sleep sync`

---

## Presentation Layer

### Task 10: Provider + Home/Cardio card

**Layer:** Presentation

**Files:**
- Modify: `lib/features/home/home_providers.dart` — add `latestCardioLoadScoreProvider` (watchLatest `ScoreType.cardioLoad`), mirroring `latestRecoveryScoreProvider`.
- Modify: the home screen's Cardio Load card to read it: big 0–100 number + graded zone label (Low / Steady / Elevated / High / Very High per the screen spec) + the engine's `label`/`trend`, with the "Calibrating — N more sleeps" state from `VlStatus.calibrating` and locked state when no score yet.

> Per `09-cardio-load.md`: single 0–100 score, simple gauge, short interpretation, NO contributor decomposition, read-only. Detail view (history list) is a follow-up task — out of scope for the first integration slice unless time allows.

**Verification:** `flutter analyze lib/features/home/`

**Commit:** `feat(cardio): wire Cardio Load home card`

---

## Testing

### Task 11: Engine-parity + reduction tests

**Layer:** Test (Priority 1 + 2)

**Files:**
- Create: `test/cardio_load_test.dart`

Assert the documented invariants (same approach as `recovery_stability_test.dart` — Python's seeded baseline isn't reproducible in Dart, so test invariants/directions):
- Cold-start: `bankedValidCount < 4` → `VlStatus.calibrating` with the right "N more sleeps" message.
- No valid sleep last night → `VlStatus.noData`.
- A night identical to the baseline scores ≈ 50.
- Higher trough HR and lower RMSSD push the score up (more load); higher stress pushes up.
- `<3` prior valid nights → `noData`.
- `SleepEpochsBuilder` round-trip: build epochs from synthetic samples → `reduceSession` produces the expected `hrP5`/`rmssdMedian`/`valid`.

**Verification:** `flutter test test/cardio_load_test.dart test/sleep_epochs_builder_test.dart`

**Commit:** `test(cardio): engine invariants + epoch reconstruction`

---

## Verification (whole feature)

```bash
flutter analyze lib            # 0 new issues
flutter test                   # all green
dart run build_runner build --delete-conflicting-outputs   # clean codegen
```

**Manual (on device, multi-night):**
- BLE Debug → Run All after an overnight → a `nightly_records` row is written; before 4 valid nights the Cardio card shows "Calibrating — N more sleeps".
- After the 5th qualifying wear → a 0–100 score appears, stable through the day.
- Confirm `hrP5`/`rmssdMedian`/`stressMean` in the stored record are physiologically sane (e.g. trough HR below daytime resting HR). This is the tuning checkpoint Ryan flagged — weights/floors are starting values.

---

## Open items to confirm with Ryan / flag

1. **Motion gate** — we feed `motion: false` (no per-epoch motion on H59). Confirm the band-staging `wake` exclusion is an acceptable proxy, or whether he wants a motion proxy derived from HR variance.
2. **Stress availability** — `stressMean` needs scheduled stress samples in the sleep window; if stress scheduled-monitoring is off, `stressMean` is NaN but the night can still be valid (stress isn't a validity gate). Verify that matches his intent.
3. **Epoch resolution** — 1-min grid with real-sample bucketing (no fabricated fill). Confirm acceptable vs. his assumption of dense per-minute device epochs.

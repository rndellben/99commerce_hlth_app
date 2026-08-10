// Step-bucket day window — rank 3 of `docs/plans/2026-08-10-coverage-audit.md`
// §1, test #2 of §4.
//
// `_dayWindow` (step_bucket_repository.dart:101-108) returns
// `to = dayStart + 1 day`, i.e. the NEXT local midnight, and `getForDay` /
// `watchForDay` / `getTotalStepsForDay` feed that pair to
// `isBetweenValues(w.from, w.to)`. SQL `BETWEEN` is inclusive on BOTH ends, so
// the bucket anchored at exactly next-day local midnight belongs to two days at
// once. The band emits 15-minute slots anchored to slot starts, so a 00:00
// bucket exists on essentially every day.
//
// The same class already gets the boundary right one method down:
// `stepsInWindow` (:172-173) uses `isBiggerOrEqualValue` / `isSmallerThanValue`,
// a half-open `[from, to)`. The contract asserted here is that the two methods
// agree about the same instant.
//
// Blast radius: `getForDay` feeds `daily_metrics.active_minutes`
// (daily_aggregator.dart:258-264) -> persisted rollup -> pushed to Supabase
// (supabase_sync_repository.dart:91).
//
// Fixture: `AppDatabase(NativeDatabase.memory())` — the injectable
// `QueryExecutor` ctor (app_database.dart:47). `users` and `devices` rows are
// inserted first because `StepBuckets.userId` / `.deviceId` are FK-referenced
// (tables.dart:208-209).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// `hide StepBucket` — drift generates a row class of that name; the domain
// model of the same name is the one the repository API speaks in.
import 'package:hlth_app/core/database/app_database.dart' hide StepBucket;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';

const _userId = 'u1';
const _deviceId = 'd1';

/// UTC+8 — the offset the band ships with in the primary test market.
const _tzOffsetMin = 480;

/// A local wall-clock instant in the `_tzOffsetMin` zone, as a true UTC
/// `DateTime`. Built with `DateTime.utc` + a manual offset so the value does
/// not depend on the host machine's zone (the frame discipline
/// `_dayWindow` itself documents at step_bucket_repository.dart:96-100).
DateTime _local(int y, int m, int d, [int hh = 0, int mm = 0]) =>
    DateTime.utc(y, m, d, hh, mm).subtract(
      const Duration(minutes: _tzOffsetMin),
    );

Future<void> _seedIdentity(AppDatabase db) async {
  await db.into(db.users).insert(UsersCompanion.insert(
        id: _userId,
        createdAtUtc: 0,
        updatedAtUtc: 0,
      ));
  await db.into(db.devices).insert(DevicesCompanion.insert(
        id: _deviceId,
        userId: _userId,
        displayName: 'H59',
        pairedAtUtc: 0,
      ));
}

StepBucket _bucket({
  required String id,
  required DateTime bucketStartAt,
  required int steps,
}) =>
    StepBucket(
      id: id,
      userId: _userId,
      deviceId: _deviceId,
      bucketStartAt: bucketStartAt,
      tzOffsetMin: _tzOffsetMin,
      steps: steps,
      distanceM: steps,
      caloriesKcal: 1,
      source: DataSource.bandScheduled,
    );

void main() {
  late AppDatabase db;
  late StepBucketRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedIdentity(db);
    repo = StepBucketRepositoryImpl(db);

    // The two buckets that straddle local midnight. 23:45 is the last slot of
    // 08-10; 00:00 is the first slot of 08-11 and must NOT count toward 08-10.
    await repo.insertMany([
      _bucket(
        id: 'b-2345',
        bucketStartAt: _local(2026, 8, 10, 23, 45),
        steps: 100,
      ),
      _bucket(
        id: 'b-0000',
        bucketStartAt: _local(2026, 8, 11, 0, 0),
        steps: 100,
      ),
    ]);
  });

  group('step-bucket day window is half-open [dayStart, dayStart + 1 day)', () {
    test('getTotalStepsForDay excludes the next-day-midnight bucket', () async {
      final total = await repo.getTotalStepsForDay(
        userId: _userId,
        localDate: DateTime(2026, 8, 10),
        tzOffsetMin: _tzOffsetMin,
      );

      expect(total, 100,
          reason: 'the local 08-11 00:00 bucket belongs to 08-11 only; '
              '200 means BETWEEN counted it on both days');
    });

    test('getForDay returns exactly the one bucket inside the day', () async {
      final rows = await repo.getForDay(
        userId: _userId,
        localDate: DateTime(2026, 8, 10),
        tzOffsetMin: _tzOffsetMin,
      );

      expect(rows.map((r) => r.id).toList(), ['b-2345']);
    });

    test('getForDay and getTotalStepsForDay agree with stepsInWindow', () async {
      // stepsInWindow is the same class's half-open implementation
      // (step_bucket_repository.dart:172-173) over the identical instants.
      final viaWindow = await repo.stepsInWindow(
        userId: _userId,
        from: _local(2026, 8, 10),
        to: _local(2026, 8, 11),
      );
      final viaDay = await repo.getTotalStepsForDay(
        userId: _userId,
        localDate: DateTime(2026, 8, 10),
        tzOffsetMin: _tzOffsetMin,
      );
      final rows = await repo.getForDay(
        userId: _userId,
        localDate: DateTime(2026, 8, 10),
        tzOffsetMin: _tzOffsetMin,
      );

      expect(viaWindow, 100, reason: 'control — half-open path, already correct');
      expect(viaDay, viaWindow,
          reason: 'the two methods disagree about the same boundary instant');
      expect(rows.fold<int>(0, (a, r) => a + r.steps), viaWindow);
    });

    test('the next day claims the midnight bucket', () async {
      final total = await repo.getTotalStepsForDay(
        userId: _userId,
        localDate: DateTime(2026, 8, 11),
        tzOffsetMin: _tzOffsetMin,
      );

      // Control: the bucket is not lost by the fix, it moves to the day it
      // actually belongs to.
      expect(total, 100);
    });
  });
}

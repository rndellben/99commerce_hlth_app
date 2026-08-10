// `BpRepository.getHourlySnapshots` — rank 5 of
// `docs/plans/2026-08-10-coverage-audit.md` §1, test #4 of §4.
//
// The method's own contract is "at most one reading per clock hour ... so that
// user-selectable scheduled-monitoring cadence (15 / 30 / 60 min) doesn't
// change the algorithm's input density" (bp_repository.dart:20-25). It buckets
// by `_toSec(capturedAt) ~/ 3600` (:193) — a UTC hour. For a zone whose offset
// is not a whole number of hours (UTC+5:30, +5:45, +8:45) the bucket boundary
// sits mid-local-hour, so the 30-minute cadence the app actually ships
// (`kBpSlotMinutes = 30`, ble_service.dart:15) puts two readings in one bucket
// some hours and one in others — exactly the density skew the method exists to
// prevent.
//
// It also inherits `getInRange`'s `isBetweenValues` (:113), inclusive on both
// ends, so a reading stamped at exactly `to` is counted inside the window. Every
// sleep-window query passes `session.endedAt` as `to`, and the sleep window is
// specified half-open, `[bedtime, wake)` (CLAUDE.md).
//
// Blast radius: this is the ONLY BP path into the rollup —
// daily_aggregator.dart:204 (sleep window) and :214 (day fallback) ->
// `daily_metrics.systolic/diastolic` -> persisted, scored, and mirrored to
// Supabase (supabase_sync_repository.dart:77-78).
//
// Fixture: `AppDatabase(NativeDatabase.memory())` — the injectable
// `QueryExecutor` ctor (app_database.dart:47). `users` and `devices` rows are
// inserted first because `BpReadings.userId` / `.deviceId` are FK-referenced
// (tables.dart:184-185).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// `hide BpReading` — drift generates a row class of that name; the domain model
// of the same name is the one the repository API speaks in.
import 'package:hlth_app/core/database/app_database.dart' hide BpReading;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';

const _userId = 'u1';
const _deviceId = 'd1';

/// UTC+5:30 — India. A half-hour zone is the whole point: its local hour
/// boundaries land at :30 past every UTC hour.
const _tzOffsetMin = 330;

/// A local wall-clock instant in the `_tzOffsetMin` zone, as a true UTC
/// `DateTime`. Built with `DateTime.utc` + a manual offset so the value does
/// not depend on the host machine's zone.
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

BpReading _reading({
  required String id,
  required DateTime capturedAt,
  required int sbp,
}) =>
    BpReading(
      id: id,
      userId: _userId,
      deviceId: _deviceId,
      capturedAt: capturedAt,
      tzOffsetMin: _tzOffsetMin,
      systolicMmhg: sbp,
      diastolicMmhg: sbp - 40,
      pulseBpm: 70,
      derivation: BpDerivation.bandSensor,
      source: DataSource.bandScheduled,
    );

void main() {
  late AppDatabase db;
  late BpRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedIdentity(db);
    repo = BpRepositoryImpl(db);
  });

  group('getHourlySnapshots buckets on LOCAL clock hours', () {
    test('a half-hour zone gets one reading per local hour, not per UTC hour',
        () async {
      // Local 01:15 and 01:45 are the same local hour; 02:15 is the next one.
      // In UTC they are 19:45, 20:15 and 20:45 — so UTC-hour bucketing splits
      // the local 01:00 hour across two buckets and merges 01:45 with 02:15.
      await repo.insertMany([
        _reading(
            id: 'r-0115', capturedAt: _local(2026, 8, 10, 1, 15), sbp: 110),
        _reading(
            id: 'r-0145', capturedAt: _local(2026, 8, 10, 1, 45), sbp: 120),
        _reading(
            id: 'r-0215', capturedAt: _local(2026, 8, 10, 2, 15), sbp: 130),
      ]);

      final rows = await repo.getHourlySnapshots(
        userId: _userId,
        from: _local(2026, 8, 10, 1),
        to: _local(2026, 8, 10, 3),
      );

      expect(rows.map((r) => r.id).toList(), ['r-0115', 'r-0215'],
          reason: 'one snapshot per LOCAL hour, first sample in each; '
              "['r-0115','r-0145'] means the buckets are UTC hours");
    });

    test('density does not change with the 30-min band cadence', () async {
      // Same two local hours, but sampled every 30 min from the top of the
      // hour — the cadence `kBpSlotMinutes` actually ships. Two local hours in
      // range must yield two snapshots regardless of cadence.
      await repo.insertMany([
        for (var i = 0; i < 4; i++)
          _reading(
            id: 'r-$i',
            capturedAt: _local(2026, 8, 10, 1).add(Duration(minutes: 30 * i)),
            sbp: 110 + i,
          ),
      ]);

      final rows = await repo.getHourlySnapshots(
        userId: _userId,
        from: _local(2026, 8, 10, 1),
        to: _local(2026, 8, 10, 3),
      );

      expect(rows.length, 2,
          reason: 'local hours 01:00 and 02:00 -> 2 snapshots');
      expect(rows.map((r) => r.id).toList(), ['r-0', 'r-2']);
    });
  });

  group('getHourlySnapshots window is half-open [from, to)', () {
    test('a reading stamped at exactly `to` is excluded', () async {
      await repo.insertMany([
        _reading(
            id: 'r-0115', capturedAt: _local(2026, 8, 10, 1, 15), sbp: 110),
        _reading(id: 'r-to', capturedAt: _local(2026, 8, 10, 3), sbp: 140),
      ]);

      final rows = await repo.getHourlySnapshots(
        userId: _userId,
        from: _local(2026, 8, 10, 1),
        to: _local(2026, 8, 10, 3),
      );

      expect(rows.map((r) => r.id), isNot(contains('r-to')),
          reason: 'the sleep window is [bedtime, wake); a sample at exactly '
              '`wake` belongs to the following window');
      expect(rows.map((r) => r.id).toList(), ['r-0115']);
    });

    test('a reading stamped at exactly `from` is included', () async {
      // Control for the half-open contract: only the upper bound moves.
      await repo.insertMany([
        _reading(id: 'r-from', capturedAt: _local(2026, 8, 10, 1), sbp: 110),
      ]);

      final rows = await repo.getHourlySnapshots(
        userId: _userId,
        from: _local(2026, 8, 10, 1),
        to: _local(2026, 8, 10, 3),
      );

      expect(rows.map((r) => r.id).toList(), ['r-from']);
    });
  });
}

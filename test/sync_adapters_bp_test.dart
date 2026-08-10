import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/sync_adapters.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';

/// Unit tests for the scheduled-BP day adapter: it maps the SDK's
/// `{readings:[{time,sbp,dbp}]}` shape to canonical BpReadings, drops the
/// band's non-convergence sentinels, and assigns deterministic ids so a
/// full-day re-pull on every sync tick overwrites instead of duplicating.
void main() {
  const tEpochSec = 1780000800; // 2026-06-04 22:00:00 UTC

  Map<String, dynamic> native(List<Map<String, dynamic>> readings) =>
      {'readings': readings};

  test('maps sbp/dbp + UTC time, tags provenance', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out, hasLength(1));
    final r = out.single;
    expect(r.systolicMmhg, 122);
    expect(r.diastolicMmhg, 78);
    expect(r.capturedAt,
        DateTime.fromMillisecondsSinceEpoch(tEpochSec * 1000, isUtc: true));
    expect(r.source, DataSource.bandScheduled);
    expect(r.derivation, BpDerivation.bandSensor);
  });

  test('drops non-convergence sentinels (sbp<=0 or dbp<=0) and time<=0', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 0, 'dbp': 80}, // band didn't converge
        {'time': tEpochSec + 3600, 'sbp': 120, 'dbp': 0},
        {'time': 0, 'sbp': 118, 'dbp': 76}, // no timestamp
        {'time': tEpochSec + 7200, 'sbp': 119, 'dbp': 77}, // valid
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out, hasLength(1));
    expect(out.single.systolicMmhg, 119);
  });

  test('id is deterministic per (deviceId, second) — re-pull overwrites', () {
    final first = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd',
    ).single;
    final second = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 125, 'dbp': 80}, // same instant, new value
      ]),
      userId: 'u',
      deviceId: 'd',
    ).single;
    // Same id → insertOnConflictUpdate overwrites rather than duplicating.
    expect(first.id, second.id);
    // Different device → different id.
    final other = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd2',
    ).single;
    expect(other.id, isNot(first.id));
  });

  test('accepts millisecond timestamps (magnitude auto-detect)', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec * 1000, 'sbp': 120, 'dbp': 80},
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out.single.capturedAt,
        DateTime.fromMillisecondsSinceEpoch(tEpochSec * 1000, isUtc: true));
  });

  test('empty / missing readings → empty list', () {
    expect(bpFromNative(const {}, userId: 'u', deviceId: 'd'), isEmpty);
    expect(bpFromNative(native(const []), userId: 'u', deviceId: 'd'), isEmpty);
  });

  group('bpTimingFromNative (autonomous hourly buffer)', () {
    Map<String, dynamic> timing(List<Map<String, dynamic>> readings) => {
          'year': 2026,
          'month': 7,
          'day': 20,
          'timeDelay': 60,
          'readings': readings,
        };

    test('converts hourly HR → sbp/dbp; hourly local time → UTC', () {
      final out = bpTimingFromNative(
        timing([
          {'timeMinute': 120, 'hr': 107}, // 02:00 local
          {'timeMinute': 180, 'hr': 62}, // 03:00 local
        ]),
        userId: 'u',
        deviceId: 'd',
        age: 30,
      );
      expect(out, hasLength(2));
      // sbp/dbp are the BpFormula estimate — sanity, not exact: physiological
      // range and dbp strictly below sbp.
      for (final r in out) {
        expect(r.systolicMmhg, inInclusiveRange(70, 200));
        expect(r.diastolicMmhg, lessThan(r.systolicMmhg));
        expect(r.source, DataSource.bandScheduled);
        expect(r.derivation, BpDerivation.bandSensor);
        expect(r.capturedAt.isUtc, isTrue);
      }
      // Higher HR → higher sbp (HR-driven model).
      expect(out[0].systolicMmhg, greaterThan(out[1].systolicMmhg));
      // 02:00 local wall-clock maps to the same instant as DateTime(local).
      expect(out[0].capturedAt,
          DateTime(2026, 7, 20, 2).toUtc());
      expect(out[1].capturedAt,
          DateTime(2026, 7, 20, 3).toUtc());
    });

    test('deterministic id per (deviceId, hour) — re-pull overwrites', () {
      final a = bpTimingFromNative(
          timing([
            {'timeMinute': 120, 'hr': 80}
          ]),
          userId: 'u',
          deviceId: 'd',
          age: 40);
      final b = bpTimingFromNative(
          timing([
            {'timeMinute': 120, 'hr': 99} // same hour, different HR
          ]),
          userId: 'u',
          deviceId: 'd',
          age: 40);
      expect(a.single.id, b.single.id); // same slot → same id → upsert
      expect(a.single.id, startsWith('bptiming:d:'));
    });

    test('drops invalid rows (hr<=0, negative minute) and missing date', () {
      final out = bpTimingFromNative(
        timing([
          {'timeMinute': 120, 'hr': 0},
          {'timeMinute': -1, 'hr': 70},
          {'timeMinute': 240, 'hr': 75},
        ]),
        userId: 'u',
        deviceId: 'd',
        age: 30,
      );
      expect(out, hasLength(1));
      expect(bpTimingFromNative(const {}, userId: 'u', deviceId: 'd', age: 30),
          isEmpty);
    });
  });

  group('bpHourlyFromHrSamples (today, derived from live HR)', () {
    HrSample hr(DateTime capturedAtUtc, int bpm) => HrSample(
          id: 'hr:${capturedAtUtc.toIso8601String()}',
          userId: 'u',
          deviceId: 'd',
          capturedAt: capturedAtUtc,
          tzOffsetMin: 0,
          bpm: bpm,
          intervalMin: 5,
          isResting: false,
          source: DataSource.bandScheduled,
        );

    test('one reading per clock-hour using the hourly median HR', () {
      final out = bpHourlyFromHrSamples(
        [
          hr(DateTime.utc(2026, 7, 21, 2, 5), 60),
          hr(DateTime.utc(2026, 7, 21, 2, 25), 80), // median of hour 02
          hr(DateTime.utc(2026, 7, 21, 2, 55), 100),
          hr(DateTime.utc(2026, 7, 21, 3, 10), 70),
        ],
        userId: 'u',
        deviceId: 'd',
        age: 30,
        tzOffsetMin: 0, // treat capturedAt as local so HH:00 is predictable
      );
      expect(out, hasLength(2));
      // Hour 02 uses the median (80), not min/max.
      expect(out[0].pulseBpm, 80);
      expect(out[0].capturedAt, DateTime.utc(2026, 7, 21, 2));
      expect(out[1].capturedAt, DateTime.utc(2026, 7, 21, 3));
      for (final r in out) {
        expect(r.systolicMmhg, inInclusiveRange(70, 200));
        expect(r.diastolicMmhg, lessThan(r.systolicMmhg));
        expect(r.source, DataSource.bandScheduled);
        expect(r.derivation, BpDerivation.bandSensor);
      }
    });

    test('id scheme matches the buffer path so tomorrow upserts, not dupes', () {
      // Both paths anchor on local wall-clock (buffer via DateTime(y,m,d);
      // derived via the phone tz). Use machine-local time on both sides so the
      // instant — and therefore the id — is identical, mirroring production.
      final derived = bpHourlyFromHrSamples(
        [hr(DateTime(2026, 7, 21, 2, 30), 107)], // local 02:30
        userId: 'u',
        deviceId: 'd',
        age: 30,
      );
      // Same local hour via the buffer path → identical id (upsert, no dup).
      final buffered = bpTimingFromNative(
        {
          'year': 2026,
          'month': 7,
          'day': 21,
          'timeDelay': 60,
          'readings': [
            {'timeMinute': 120, 'hr': 107} // 02:00 local
          ],
        },
        userId: 'u',
        deviceId: 'd',
        age: 30,
      );
      expect(derived.single.id, buffered.single.id);
      expect(derived.single.systolicMmhg, buffered.single.systolicMmhg);
      expect(derived.single.id, startsWith('bptiming:d:'));
    });

    test('slotMinutes:30 yields a reading every half-hour', () {
      final out = bpHourlyFromHrSamples(
        [
          hr(DateTime.utc(2026, 7, 21, 2, 5), 60),
          hr(DateTime.utc(2026, 7, 21, 2, 20), 62), // slot 02:00
          hr(DateTime.utc(2026, 7, 21, 2, 40), 90), // slot 02:30
          hr(DateTime.utc(2026, 7, 21, 3, 10), 70), // slot 03:00
        ],
        userId: 'u',
        deviceId: 'd',
        age: 30,
        tzOffsetMin: 0,
        slotMinutes: 30,
      );
      expect(out.map((r) => r.capturedAt), [
        DateTime.utc(2026, 7, 21, 2, 0),
        DateTime.utc(2026, 7, 21, 2, 30),
        DateTime.utc(2026, 7, 21, 3, 0),
      ]);
      // The on-the-hour slot still aligns with the hourly buffer id.
      expect(out.first.id, startsWith('bptiming:d:'));
    });

    test('skips non-positive bpm; empty in → empty out', () {
      final out = bpHourlyFromHrSamples(
        [
          hr(DateTime.utc(2026, 7, 21, 4, 5), 0),
          hr(DateTime.utc(2026, 7, 21, 4, 15), -3),
        ],
        userId: 'u',
        deviceId: 'd',
        age: 30,
        tzOffsetMin: 0,
      );
      expect(out, isEmpty);
      expect(
          bpHourlyFromHrSamples(const [],
              userId: 'u', deviceId: 'd', age: 30),
          isEmpty);
    });
  });
}

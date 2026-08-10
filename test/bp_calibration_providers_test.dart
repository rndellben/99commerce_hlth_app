import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/providers/bp_calibration_providers.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';

/// These assert *which branch of the app's own model* runs — not that any
/// displayed BP number is accurate. `bp_formula.dart` has no pressure
/// sensor and no pulse-transit-time term; both branches are arithmetic
/// over HR and age (CLAUDE.md, "Blood pressure"). The defect under test is
/// that the display contradicted the model by a constant +9…+49 mmHg.
void main() {
  group('calibratedLatestBpProvider — anchor with no HR', () {
    test('takes the constant-offset branch, not the HR-coupled one', () async {
      final container = _container(
        cal: _cal(hrAtCalibration: null),
        reading: _reading(sbp: 118, dbp: 76, pulseBpm: 70),
      );

      final v = await _settled(container);

      // Constant offset: raw 118 + (cuff 130 − 120) = 128,
      //                  raw  76 + (cuff  85 −  80) =  81.
      expect(v.displaySbp, 128);
      expect(v.displayDbp, 81);
      expect(v.isCalibrated, isTrue);
      // The HR-coupled branch against a zero anchor HR would give
      // 130 + 70 × 0.45 = 161.5 → 162, and 162 − 45 = 117.
      expect(v.displaySbp, isNot(162));
      expect(v.displayDbp, isNot(117));
    });

    test('reading without a pulse lands on the same value', () async {
      final container = _container(
        cal: _cal(hrAtCalibration: null),
        reading: _reading(sbp: 118, dbp: 76, pulseBpm: null),
      );

      final v = await _settled(container);

      expect(v.displaySbp, 128);
      expect(v.displayDbp, 81);
      expect(v.isCalibrated, isTrue);
    });
  });

  group('calibratedLatestBpProvider — anchor with HR', () {
    test('still takes the HR-coupled branch', () async {
      final container = _container(
        cal: _cal(hrAtCalibration: 60),
        reading: _reading(sbp: 118, dbp: 76, pulseBpm: 70),
      );

      final v = await _settled(container);

      // 130 + (70 − 60) × 0.45 = 134.5 → 135; dbp preserves the 45 gap.
      expect(v.displaySbp, 135);
      expect(v.displayDbp, 90);
      expect(v.isCalibrated, isTrue);
    });

    test('a reading without a pulse falls back to the constant offset',
        () async {
      final container = _container(
        cal: _cal(hrAtCalibration: 60),
        reading: _reading(sbp: 118, dbp: 76, pulseBpm: null),
      );

      final v = await _settled(container);

      expect(v.displaySbp, 128);
      expect(v.displayDbp, 81);
      expect(v.isCalibrated, isTrue);
    });
  });

  group('calibratedLatestBpProvider — no calibration', () {
    test('passes the raw band values through uncalibrated', () async {
      final container = _container(
        cal: null,
        reading: _reading(sbp: 118, dbp: 76, pulseBpm: 70),
      );

      final v = await _settled(container);

      expect(v.displaySbp, 118);
      expect(v.displayDbp, 76);
      expect(v.isCalibrated, isFalse);
    });
  });

  // The BP trend chart had its own copy of the anchor logic carrying the
  // same defect (`_bpAnchorFor`, blood_pressure_screen.dart). It now calls
  // `calibrateBpReading`, so every chart point resolves through the code
  // asserted here and cannot disagree with the headline.
  group('calibrateBpReading — the seam the chart and headline share', () {
    test('HR-less anchor: constant offset for every point', () {
      final cal = _cal(hrAtCalibration: null);
      final points = [
        _reading(sbp: 118, dbp: 76, pulseBpm: 70),
        _reading(sbp: 124, dbp: 80, pulseBpm: 95),
        _reading(sbp: 112, dbp: 72, pulseBpm: null),
      ].map((r) => calibrateBpReading(reading: r, cal: cal)).toList();

      expect(points.map((c) => c.sbp), [128, 134, 122]);
      expect(points.map((c) => c.dbp), [81, 85, 77]);
      // The buggy branch collapsed every point onto cuffSbp + 0.45 × pulse,
      // flattening the trend toward the anchor regardless of the raw value.
      expect(points.map((c) => c.sbp), isNot(contains(162)));
    });

    test('anchored with HR: chart points track the reading pulse', () {
      final cal = _cal(hrAtCalibration: 60);
      final points = [
        _reading(sbp: 118, dbp: 76, pulseBpm: 70),
        _reading(sbp: 124, dbp: 80, pulseBpm: 80),
      ].map((r) => calibrateBpReading(reading: r, cal: cal)).toList();

      // 130 + (70 − 60) × 0.45 = 134.5 → 135; 130 + (80 − 60) × 0.45 = 139.
      expect(points.map((c) => c.sbp), [135, 139]);
    });

    test('chart and headline resolve one reading identically', () async {
      final cal = _cal(hrAtCalibration: null);
      final reading = _reading(sbp: 118, dbp: 76, pulseBpm: 70);
      final headline = await _settled(_container(cal: cal, reading: reading));
      final point = calibrateBpReading(reading: reading, cal: cal);

      expect(point.sbp, headline.displaySbp);
      expect(point.dbp, headline.displayDbp);
      expect(point.appCalibrated, headline.isCalibrated);
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

BpCalibration _cal({required int? hrAtCalibration}) => BpCalibration(
      id: 'cal-1',
      userId: 'local-user-v1',
      capturedAt: DateTime.utc(2026, 8, 9, 12),
      cuffSystolic: 130,
      cuffDiastolic: 85,
      hrAtCalibration: hrAtCalibration,
      createdAt: DateTime.utc(2026, 8, 9, 12),
    );

BpReading _reading({required int sbp, required int dbp, int? pulseBpm}) =>
    BpReading(
      id: 'bp-1',
      userId: 'local-user-v1',
      deviceId: 'dev-1',
      capturedAt: DateTime.utc(2026, 8, 10, 7),
      tzOffsetMin: 0,
      systolicMmhg: sbp,
      diastolicMmhg: dbp,
      pulseBpm: pulseBpm,
      derivation: BpDerivation.hrEstimate,
      source: DataSource.bandScheduled,
    );

ProviderContainer _container({
  required BpCalibration? cal,
  required BpReading reading,
}) {
  final container = ProviderContainer(
    overrides: [
      bpCalibrationRepositoryProvider.overrideWithValue(_FakeCalRepo(cal)),
      bpRepositoryProvider.overrideWithValue(_FakeBpRepo(reading)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// `calibratedLatestBpProvider` rebuilds once `activeBpCalibrationProvider`
/// resolves — its first emission is the uncalibrated flash documented as
/// rank 17 of the coverage audit. Pump until both streams have landed.
Future<BpReadingWithCalibration> _settled(ProviderContainer container) async {
  BpReadingWithCalibration? last;
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
    final v = container.read(calibratedLatestBpProvider).valueOrNull;
    if (v != null) {
      last = v;
      // A null calibration never becomes calibrated; stop at the first value.
      if (v.isCalibrated) return v;
    }
  }
  if (last != null) return last;
  fail('calibratedLatestBpProvider never emitted a value');
}

// ---------------------------------------------------------------------------
// Fakes — hand-written over the abstract interfaces, no mocking library.
// ---------------------------------------------------------------------------

/// Base that throws for any repo member the provider does not touch.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeCalRepo extends _Fake implements BpCalibrationRepository {
  _FakeCalRepo(this._active);
  final BpCalibration? _active;

  @override
  Stream<BpCalibration?> watchActiveForUser(String userId) =>
      Stream.value(_active);
}

class _FakeBpRepo extends _Fake implements BpRepository {
  _FakeBpRepo(this._latest);
  final BpReading? _latest;

  @override
  Stream<BpReading?> watchLatest({required String userId}) =>
      Stream.value(_latest);
}

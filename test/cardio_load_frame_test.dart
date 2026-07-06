import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/nightly_record_row.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/nightly_record_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/core/services/cardio_load_service.dart';

/// CardioLoadService time-frame guard.
///
/// Sleep sessions, HR, HRV and stress are ALL stored in true UTC, so the
/// service queries each metric with the session bounds directly — no tz
/// conversion. This test proves HRV that falls inside the session window is
/// used, and that an 8h-shifted decoy (awake-evening HRV) is NOT — i.e. we
/// must query the session window as-is. A regression that re-adds a
/// `subtract(tzOffsetMin)` "bridge" would grab the decoy and this fails.
void main() {
  const userId = 'u';
  const tzMin = 480; // UTC+8

  // Session window: local 03:37–07:37 stored in true UTC. For a UTC+8 sleeper
  // that's 19:37Z→23:37Z the prior day (matches the real device: a user who
  // slept 03:37 local had startedAt render 03:37 via .toLocal()).
  final start = DateTime.utc(2026, 7, 2, 19, 37);
  final end = start.add(const Duration(hours: 4)); // 23:37Z

  final session = SleepSession(
    id: 's1',
    userId: userId,
    deviceId: 'd',
    startedAt: start,
    endedAt: end,
    tzOffsetMin: tzMin,
    type: SleepSessionType.night,
    protocolVersion: 2,
    totalMin: 240,
    deepMin: 240,
    source: DataSource.bandScheduled,
  );

  final epochs = [
    SleepEpoch(
      id: 'e1',
      sessionId: 's1',
      userId: userId,
      startedAt: start,
      durationMin: 240,
      stage: SleepStage.deep,
      source: DataSource.bandScheduled,
    ),
  ];

  final hr = [
    for (var i = 0; i < 60; i++)
      HrSample(
        id: 'hr$i',
        userId: userId,
        deviceId: 'd',
        capturedAt: start.add(Duration(minutes: i)),
        tzOffsetMin: tzMin,
        bpm: 55 + (i % 5),
        intervalMin: 1,
        isResting: true,
        source: DataSource.bandScheduled,
      ),
  ];

  // In-window sleep HRV (rmssd 40..69) …
  final sleepHrv = [
    for (var i = 0; i < 30; i++)
      HrvSample(
        id: 'hrv$i',
        userId: userId,
        deviceId: 'd',
        capturedAt: start.add(Duration(minutes: i * 2)),
        tzOffsetMin: tzMin,
        rmssdMs: 40.0 + i,
        source: DataSource.bandScheduled,
      ),
  ];
  // … plus a DECOY 8h earlier (awake evening), rmssd 99. Only a wrongly
  // tz-shifted query would pick these up.
  final decoyHrv = [
    for (var i = 0; i < 30; i++)
      HrvSample(
        id: 'decoy$i',
        userId: userId,
        deviceId: 'd',
        capturedAt: start
            .subtract(const Duration(minutes: 480))
            .add(Duration(minutes: i * 2)),
        tzOffsetMin: tzMin,
        rmssdMs: 99.0,
        source: DataSource.bandScheduled,
      ),
  ];

  final stress = [
    for (var i = 0; i < 10; i++)
      StressSample(
        id: 'st$i',
        userId: userId,
        deviceId: 'd',
        capturedAt: start.add(Duration(minutes: i * 5)),
        tzOffsetMin: tzMin,
        stressScore: 20 + i,
        rangeMin: 30,
        source: DataSource.bandScheduled,
      ),
  ];

  NightlyRecordRow baseline(int i) => NightlyRecordRow(
        id: 'h$i',
        userId: userId,
        localDate: DateTime.utc(2026, 6, 25 + i),
        hrP5: 55,
        rmssdMedian: 45,
        stressMean: 30,
        coverage: 0.9,
        valid: true,
        computedAt: DateTime.utc(2026, 6, 25 + i, 8),
        algorithmVersion: 'test',
      );
  final history = [for (var i = 0; i < 6; i++) baseline(i)];

  test('uses in-window sleep HRV (not the 8h-shifted decoy) → night valid', () async {
    final nightly = _FakeNightlyRepo(history);
    final scores = _FakeScoreRepo();
    final svc = CardioLoadService(
      sleepRepo: _FakeSleepRepo(session, epochs),
      hrRepo: _FakeHrRepo(hr),
      hrvRepo: _FakeHrvRepo([...sleepHrv, ...decoyHrv]),
      stressRepo: _FakeStressRepo(stress),
      nightlyRepo: nightly,
      scoreRepo: scores,
    );

    final result = await svc.computeForLatestNight(userId: userId);

    expect(nightly.upserted, isNotNull);
    expect(nightly.upserted!.rmssdMedian, isNotNull);
    // Median of the in-window samples (40..69) → ~54, and crucially NOT the
    // decoy value 99 that a wrongly tz-shifted query would return.
    expect(nightly.upserted!.rmssdMedian!, lessThan(80),
        reason: 'must use sleep HRV, not the 8h-shifted awake decoy (99)');
    expect(nightly.upserted!.valid, isTrue);
    expect(result?.produced, isTrue, reason: result?.message);
    expect(scores.upserted, isNotNull);
  });
}

/// Base that throws for any repo method the service does not touch.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeSleepRepo extends _Fake implements SleepRepository {
  _FakeSleepRepo(this._session, this._epochs);
  final SleepSession _session;
  final List<SleepEpoch> _epochs;

  @override
  Stream<SleepSession?> watchMostRecentNight(String userId) =>
      Stream.value(_session);

  @override
  Future<List<SleepEpoch>> getEpochsForSession(String sessionId) async =>
      _epochs;
}

class _FakeHrRepo extends _Fake implements HrRepository {
  _FakeHrRepo(this._samples);
  final List<HrSample> _samples;

  @override
  Future<List<HrSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async =>
      _samples
          .where((s) =>
              !s.capturedAt.isBefore(from) && !s.capturedAt.isAfter(to))
          .toList();
}

class _FakeHrvRepo extends _Fake implements HrvRepository {
  _FakeHrvRepo(this._samples);
  final List<HrvSample> _samples;

  @override
  Future<List<HrvSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async =>
      _samples
          .where((s) =>
              !s.capturedAt.isBefore(from) && !s.capturedAt.isAfter(to))
          .toList();
}

class _FakeStressRepo extends _Fake implements StressRepository {
  _FakeStressRepo(this._samples);
  final List<StressSample> _samples;

  @override
  Future<List<StressSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async =>
      _samples
          .where((s) =>
              !s.capturedAt.isBefore(from) && !s.capturedAt.isAfter(to))
          .toList();
}

class _FakeNightlyRepo extends _Fake implements NightlyRecordRepository {
  _FakeNightlyRepo(this._history);
  final List<NightlyRecordRow> _history;
  NightlyRecordRow? upserted;

  @override
  Future<List<NightlyRecordRow>> getHistoryBefore({
    required String userId,
    required DateTime beforeDate,
    int limit = 30,
  }) async =>
      _history;

  @override
  Future<void> upsert(NightlyRecordRow row) async {
    upserted = row;
  }
}

class _FakeScoreRepo extends _Fake implements ScoreRepository {
  Score? upserted;

  @override
  Future<void> upsert(Score score) async {
    upserted = score;
  }
}

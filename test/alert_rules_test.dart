import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/breathing_disruption_rule.dart';
import 'package:hlth_app/core/services/alerts/hypertension_risk_rule.dart';
import 'package:hlth_app/core/services/alerts/morning_report_rule.dart';

/// Rule-level tests for the three alerts added 2026-07-06 (Ryan's June 17
/// list + the morning metrics push). Evaluator plumbing (rate-limit, logging)
/// is covered separately in alert_evaluator_test.dart; here each rule's
/// conservative gates are exercised against fake repos.
void main() {
  const userId = 'u';

  // ── Hypertension risk ────────────────────────────────────────────────
  group('HypertensionRiskRule', () {
    final now = DateTime(2026, 7, 6, 9); // local morning
    final today = DateTime(2026, 7, 6);

    DailyMetrics day(DateTime d, {int? sbp}) => DailyMetrics(
          id: 'm-${d.day}',
          userId: userId,
          localDate: d,
          tzOffsetMin: 480,
          systolicMmhg: sbp,
          diastolicMmhg: sbp == null ? null : 80,
          computedAt: d,
          algorithmVersion: 't',
          source: DataSource.appRecomputed,
        );

    BpCalibration cal({int cuffSbp = 120, int cuffDbp = 80}) => BpCalibration(
          id: 'c1',
          userId: userId,
          capturedAt: today,
          cuffSystolic: cuffSbp,
          cuffDiastolic: cuffDbp,
          createdAt: today,
        );

    List<DailyMetrics> history({required int todaySbp, required int priorSbp}) => [
          for (var i = 7; i >= 1; i--)
            day(today.subtract(Duration(days: i)), sbp: priorSbp),
          day(today, sbp: todaySbp),
        ];

    HypertensionRiskRule rule({
      List<DailyMetrics> rows = const [],
      BpCalibration? calibration,
    }) =>
        HypertensionRiskRule(
          dailyRepo: _FakeDailyRepo(rows: rows),
          calibrationRepo: _FakeCalRepo(calibration),
        );

    AlertContext ctx() => AlertContext(userId: userId, now: now);

    test('no active calibration → never fires, even with elevated BP', () async {
      final r = rule(rows: history(todaySbp: 150, priorSbp: 115));
      expect(await r.evaluate(ctx()), isNull);
    });

    test('delta below 15 over own average → null', () async {
      final r = rule(
        rows: history(todaySbp: 128, priorSbp: 115), // delta 13
        calibration: cal(),
      );
      expect(await r.evaluate(ctx()), isNull);
    });

    test('too few prior BP days → null', () async {
      final r = rule(
        rows: [
          day(today.subtract(const Duration(days: 1)), sbp: 115),
          day(today.subtract(const Duration(days: 2)), sbp: 115),
          day(today, sbp: 140),
        ],
        calibration: cal(),
      );
      expect(await r.evaluate(ctx()), isNull);
    });

    test('absolute guard: big delta but calibrated SBP < 130 → null', () async {
      final r = rule(
        rows: history(todaySbp: 118, priorSbp: 100), // delta 18, abs low
        calibration: cal(), // cuff 120/80 → zero offset
      );
      expect(await r.evaluate(ctx()), isNull);
    });

    test('fires when delta ≥15 AND calibrated ≥130', () async {
      final r = rule(
        rows: history(todaySbp: 135, priorSbp: 115), // delta 20
        calibration: cal(), // zero offset → calibrated 135
      );
      final c = await r.evaluate(ctx());
      expect(c, isNotNull);
      expect(c!.payload!['todaySbp'], 135);
      expect(c.payload!['priorAvgSbp'], 115);
      expect(c.body, contains('aren’t a diagnosis')); // wellness framing
    });

    test('calibration offset lifts a raw-borderline value over the guard',
        () async {
      // Raw 120 + cuff(135/85) offset (+15) → calibrated 135 ≥ 130.
      final r = rule(
        rows: history(todaySbp: 120, priorSbp: 100), // delta 20
        calibration: cal(cuffSbp: 135, cuffDbp: 85),
      );
      expect(await r.evaluate(ctx()), isNotNull);
    });
  });

  // ── Breathing disruption (overnight SpO2) ───────────────────────────
  group('BreathingDisruptionRule', () {
    final wake = DateTime.utc(2026, 7, 6, 8);
    final bed = wake.subtract(const Duration(hours: 8));

    SleepSession night({DateTime? endedAt}) => SleepSession(
          id: 's1',
          userId: userId,
          deviceId: 'd',
          startedAt: bed,
          endedAt: endedAt ?? wake,
          tzOffsetMin: 480,
          type: SleepSessionType.night,
          protocolVersion: 2,
          totalMin: 480,
          deepMin: 100,
          source: DataSource.bandScheduled,
        );

    Spo2Sample bucket(int hour, int pctMin) => Spo2Sample(
          id: 'o$hour',
          userId: userId,
          deviceId: 'd',
          capturedAt: bed.add(Duration(hours: hour)),
          tzOffsetMin: 480,
          pctMin: pctMin,
          pctMax: pctMin + 2,
          bucketMin: 60,
          source: DataSource.bandScheduled,
        );

    BreathingDisruptionRule rule({
      SleepSession? session,
      List<Spo2Sample> spo2 = const [],
    }) =>
        BreathingDisruptionRule(
          sleepRepo: _FakeSleepRepo(session),
          spo2Repo: _FakeSpo2Repo(spo2),
        );

    AlertContext ctx({DateTime? now}) =>
        AlertContext(userId: userId, now: now ?? wake.add(const Duration(hours: 2)));

    test('detect() ignores zero buckets and counts low ones', () {
      final r = BreathingDisruptionRule.detect([
        bucket(0, 0), // no reading — ignored
        bucket(1, 96),
        bucket(2, 89),
        bucket(3, 88),
      ]);
      expect(r.totalBuckets, 3);
      expect(r.lowBuckets, 2);
      expect(r.minPct, 88);
    });

    test('stale night (>24h old) → null', () async {
      final r = rule(
        session: night(),
        spo2: [for (var h = 0; h < 6; h++) bucket(h, 88)],
      );
      final c = await r.evaluate(
          ctx(now: wake.add(const Duration(hours: 30))));
      expect(c, isNull);
    });

    test('thin coverage (<4 buckets) → null', () async {
      final r = rule(session: night(), spo2: [bucket(1, 85), bucket(2, 85)]);
      expect(await r.evaluate(ctx()), isNull);
    });

    test('a single low hour never fires', () async {
      final r = rule(
        session: night(),
        spo2: [bucket(0, 97), bucket(1, 96), bucket(2, 89), bucket(3, 97)],
      );
      expect(await r.evaluate(ctx()), isNull);
    });

    test('fires on ≥2 low hours with coverage', () async {
      final r = rule(
        session: night(),
        spo2: [
          bucket(0, 97),
          bucket(1, 89),
          bucket(2, 96),
          bucket(3, 87),
          bucket(4, 98),
        ],
      );
      final c = await r.evaluate(ctx());
      expect(c, isNotNull);
      expect(c!.payload!['lowBuckets'], 2);
      expect(c.payload!['minPct'], 87);
      expect(c.title.toLowerCase(), isNot(contains('apnea'))); // regulatory
    });
  });

  // ── Morning report ───────────────────────────────────────────────────
  group('MorningReportRule', () {
    final morning = DateTime(2026, 7, 6, 8); // 08:00 local
    final today = DateTime(2026, 7, 6);

    Score recovery(DateTime forDate) => Score(
          id: 'sc1',
          userId: userId,
          scoreType: ScoreType.recovery,
          computedForDate: forDate,
          score: 47.4,
          label: 'Moderate',
          provisional: false,
          components: const {},
          computedAt: forDate,
          algorithmVersion: 't',
        );

    DailyMetrics metrics() => DailyMetrics(
          id: 'm1',
          userId: userId,
          localDate: today,
          tzOffsetMin: 480,
          restingHrBpm: 67,
          sleepTotalMin: 466,
          computedAt: today,
          algorithmVersion: 't',
          source: DataSource.appRecomputed,
        );

    MorningReportRule rule({Score? score, DailyMetrics? dm}) =>
        MorningReportRule(
          scoreRepo: _FakeScoreRepo(score),
          dailyRepo: _FakeDailyRepo(forDay: dm),
        );

    test('outside the morning window → null', () async {
      final r = rule(score: recovery(today), dm: metrics());
      final c = await r.evaluate(
          AlertContext(userId: userId, now: DateTime(2026, 7, 6, 15)));
      expect(c, isNull);
    });

    test('yesterday\'s score does not count as fresh → null', () async {
      final r = rule(
          score: recovery(today.subtract(const Duration(days: 1))),
          dm: metrics());
      expect(
          await r.evaluate(AlertContext(userId: userId, now: morning)), isNull);
    });

    test('fires in the morning with the metric summary in the body', () async {
      final r = rule(score: recovery(today), dm: metrics());
      final c =
          await r.evaluate(AlertContext(userId: userId, now: morning));
      expect(c, isNotNull);
      expect(c!.body, contains('Recovery 47'));
      expect(c.body, contains('7h 46m'));
      expect(c.body, contains('67 bpm'));
    });
  });
}

/// Base that throws for any repo member a rule doesn't touch.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeDailyRepo extends _Fake implements DailyMetricsRepository {
  _FakeDailyRepo({this.rows = const [], this.forDay});
  final List<DailyMetrics> rows;
  final DailyMetrics? forDay;

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async =>
      rows;

  @override
  Future<DailyMetrics?> getForDay({
    required String userId,
    required DateTime localDate,
  }) async =>
      forDay;
}

class _FakeCalRepo extends _Fake implements BpCalibrationRepository {
  _FakeCalRepo(this._active);
  final BpCalibration? _active;

  @override
  Future<BpCalibration?> getActiveForUser(String userId) async => _active;
}

class _FakeSleepRepo extends _Fake implements SleepRepository {
  _FakeSleepRepo(this._night);
  final SleepSession? _night;

  @override
  Future<SleepSession?> getMostRecentNightFor(String userId) async => _night;
}

class _FakeSpo2Repo extends _Fake implements Spo2Repository {
  _FakeSpo2Repo(this._samples);
  final List<Spo2Sample> _samples;

  @override
  Future<List<Spo2Sample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async =>
      _samples;
}

class _FakeScoreRepo extends _Fake implements ScoreRepository {
  _FakeScoreRepo(this._current);
  final Score? _current;

  @override
  Future<Score?> getCurrent({
    required String userId,
    required ScoreType scoreType,
    required DateTime forDate,
  }) async =>
      _current;
}

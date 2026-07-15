import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/bedtime_reminder_rule.dart';
import 'package:hlth_app/core/services/notification_service.dart';

/// Past-midnight wind-down nudge. The safety property under test: it fires
/// ONLY on positive evidence of "awake right now" (phone interaction,
/// recent walking, or clearly-elevated HR — inside 00:00–04:00). A charging
/// ring, an already-asleep wearer, an ambiguous quiet-wakefulness night
/// WITHOUT phone evidence, or a daytime hour must all yield silence.
///
/// Regression anchor (2026-07-14): quiet wakefulness + recent phone use
/// MUST fire — the original rule negated the BP-tuned sleep detector, which
/// classified every motionless calm-HR wearer as asleep, so the reminder
/// never fired for the exact persona that requested it.
void main() {
  const userId = 'u';

  DailyMetrics restingRow(DateTime day) => DailyMetrics(
        id: 'm',
        userId: userId,
        localDate: DateTime(day.year, day.month, day.day),
        tzOffsetMin: 480,
        restingHrBpm: 60,
        computedAt: day,
        algorithmVersion: 't',
        source: DataSource.appRecomputed,
      );

  BedtimeReminderRule rule({
    required DateTime now,
    double? recentAvgHr,
    int recentSteps = 0,
    DateTime? phoneActiveAt,
    bool phoneUnlockedNow = false,
    bool hasBankedBaseline = true,
    List<HrSample> nightHr = const [],
  }) {
    final hrRepo = _FakeHrRepo(avg: recentAvgHr, inRange: nightHr);
    final stepRepo = _FakeStepRepo(windowSteps: recentSteps);
    final dailyRepo = _FakeDailyRepo(
      rows: hasBankedBaseline ? [restingRow(now)] : const [],
    );
    return BedtimeReminderRule(
      hrRepo: hrRepo,
      stepRepo: stepRepo,
      dailyRepo: dailyRepo,
      lastAppActiveAt: () async => phoneActiveAt,
      phoneInUseNow: () async => phoneUnlockedNow,
    );
  }

  AlertContext ctx(DateTime now) => AlertContext(userId: userId, now: now);

  group('BedtimeReminderRule — fires on positive wake evidence', () {
    test('01:10, quiet wakefulness (HR 68) + phone used 10 min ago → fires',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(
        now: now,
        recentAvgHr: 68, // inside the sleeping band — ring can't tell
        phoneActiveAt: now.subtract(const Duration(minutes: 10)),
      ).evaluate(ctx(now));
      expect(c, isNotNull, reason: 'phone interaction is irrefutable');
      expect(c!.title, 'Time to wind down');
      expect(c.body, contains('past midnight'));
      expect(c.channel, AlertChannel.retention);
      expect(c.dedupeKey, 'bedtime-2026-07-09');
      expect(c.payload!['evidence'], 'phone');
    });

    test('phone evidence works even with the ring charging (no fresh HR)',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(
        now: now,
        recentAvgHr: null, // ring off wrist
        phoneActiveAt: now.subtract(const Duration(minutes: 5)),
      ).evaluate(ctx(now));
      expect(c, isNotNull);
    });

    test('01:10, phone unlocked & in use (other app), quiet HR → fires',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 68, phoneUnlockedNow: true)
          .evaluate(ctx(now));
      expect(c, isNotNull,
          reason: 'unlocked-in-use phone must fire without opening HLTH');
      expect(c!.payload!['evidence'], 'phone-unlocked');
    });

    test('01:10, ring on, clearly awake (HR 85 vs rest 60) → fires', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 85).evaluate(ctx(now));
      expect(c, isNotNull);
      expect(c!.payload!['evidence'], startsWith('hr='));
    });

    test('01:10, walked recently (300 steps, calm HR) → fires', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 68, recentSteps: 300)
          .evaluate(ctx(now));
      expect(c, isNotNull);
      expect(c!.payload!['evidence'], 'steps=300');
    });
  });

  group('BedtimeReminderRule — stays silent without evidence', () {
    test('quiet wakefulness, no phone use → silent (ambiguous = no alarm)',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      expect(await rule(now: now, recentAvgHr: 68).evaluate(ctx(now)), isNull);
    });

    test('phone locked (screen off in pocket / asleep) → silent', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 68, phoneUnlockedNow: false)
          .evaluate(ctx(now));
      expect(c, isNull);
    });

    test('stale phone evidence (45 min ago) does not count', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(
        now: now,
        recentAvgHr: 68,
        phoneActiveAt: now.subtract(const Duration(minutes: 45)),
      ).evaluate(ctx(now));
      expect(c, isNull);
    });

    test('a few phantom steps (< threshold) do not count as walking',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 68, recentSteps: 4)
          .evaluate(ctx(now));
      expect(c, isNull);
    });

    test('no banked baseline: HR 85 alone cannot fire (no default-70 bar)',
        () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(
        now: now,
        recentAvgHr: 85,
        hasBankedBaseline: false,
      ).evaluate(ctx(now));
      expect(c, isNull);
    });

    test('23:30 — before the window → silent even with phone evidence',
        () async {
      final now = DateTime(2026, 7, 8, 23, 30);
      final c = await rule(
        now: now,
        recentAvgHr: 85,
        phoneActiveAt: now.subtract(const Duration(minutes: 1)),
      ).evaluate(ctx(now));
      expect(c, isNull);
    });

    test('04:00 — window end is exclusive → silent', () async {
      final now = DateTime(2026, 7, 9, 4, 0);
      expect(await rule(now: now, recentAvgHr: 85).evaluate(ctx(now)), isNull);
    });

    test('no fresh HR and no phone evidence → silent', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      expect(
          await rule(now: now, recentAvgHr: null).evaluate(ctx(now)), isNull);
    });

    test('already asleep (HR 68 within rest+20, no steps) → silent', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      expect(await rule(now: now, recentAvgHr: 68).evaluate(ctx(now)), isNull);
    });

    test('woke after sleeping (calm-HR night on record) → silent even with '
        'phone unlocked', () async {
      // Slept 23:00–03:00 (calm samples every 10 min), wakes 03:15 and
      // unlocks the phone — the post-sleep guard must suppress the nudge.
      final now = DateTime(2026, 7, 9, 3, 15);
      final night = _hrRun(
        from: DateTime(2026, 7, 8, 23, 0),
        to: DateTime(2026, 7, 9, 3, 0),
        bpm: 66, // ≤ rest 60 + 20
      );
      final c = await rule(
        now: now,
        recentAvgHr: 72,
        phoneUnlockedNow: true,
        nightHr: night,
      ).evaluate(ctx(now));
      expect(c, isNull, reason: 'already slept tonight — no wind-down nudge');
    });

    test('still up scrolling (no calm hour on record) → fires', () async {
      // Awake all evening: HR bounces above the sleeping ceiling every
      // 30 min, so no contiguous sleep-like hour exists.
      final now = DateTime(2026, 7, 9, 1, 10);
      final night = <HrSample>[];
      var t = DateTime(2026, 7, 8, 21, 0);
      var i = 0;
      while (t.isBefore(now)) {
        night.add(_hr(t, i.isEven ? 74 : 88)); // 88 > 60+20 every other slot
        t = t.add(const Duration(minutes: 30));
        i++;
      }
      final c = await rule(
        now: now,
        recentAvgHr: 74,
        phoneUnlockedNow: true,
        nightHr: night,
      ).evaluate(ctx(now));
      expect(c, isNotNull);
    });
  });
}

HrSample _hr(DateTime at, int bpm) => HrSample(
      id: 'h-\${at.millisecondsSinceEpoch}',
      userId: 'u',
      deviceId: 'd',
      capturedAt: at.toUtc(),
      tzOffsetMin: 480,
      bpm: bpm,
      intervalMin: 10,
      isResting: false,
      source: DataSource.bandScheduled,
    );

List<HrSample> _hrRun({
  required DateTime from,
  required DateTime to,
  required int bpm,
}) {
  final out = <HrSample>[];
  var t = from;
  while (t.isBefore(to)) {
    out.add(_hr(t, bpm));
    t = t.add(const Duration(minutes: 10));
  }
  return out;
}

class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeHrRepo extends _Fake implements HrRepository {
  _FakeHrRepo({this.avg, this.inRange = const []});
  final double? avg;
  final List<HrSample> inRange;

  @override
  Future<double?> averageInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async =>
      avg;

  @override
  Future<List<HrSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async =>
      inRange
          .where((s) =>
              !s.capturedAt.isBefore(from.toUtc()) &&
              s.capturedAt.isBefore(to.toUtc()))
          .toList();
}

class _FakeStepRepo extends _Fake implements StepBucketRepository {
  _FakeStepRepo({this.windowSteps = 0});
  final int windowSteps;

  @override
  Future<int> stepsInWindow({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async =>
      windowSteps;

}

class _FakeDailyRepo extends _Fake implements DailyMetricsRepository {
  _FakeDailyRepo({this.rows = const []});
  final List<DailyMetrics> rows;

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async =>
      rows;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/bedtime_reminder_rule.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';

/// Past-midnight wind-down nudge. The safety property under test: it fires
/// ONLY on positive evidence of "awake right now" (fresh HR + awake verdict,
/// inside 00:00–04:00) — a charging ring, an already-asleep wearer, or a
/// daytime hour must all yield silence.
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

  BedtimeReminderRule rule({required DateTime now, double? recentAvgHr}) {
    final hrRepo = _FakeHrRepo(avg: recentAvgHr);
    return BedtimeReminderRule(
      hrRepo: hrRepo,
      sleepOnset: SleepOnsetDetector(
        hrRepo: hrRepo,
        stepRepo: _FakeStepRepo(),
        dailyRepo: _FakeDailyRepo(rows: [restingRow(now)]),
        now: () => now,
      ),
    );
  }

  AlertContext ctx(DateTime now) => AlertContext(userId: userId, now: now);

  group('BedtimeReminderRule', () {
    test('01:10, ring on, clearly awake (HR 85 vs rest 60) → fires', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      final c = await rule(now: now, recentAvgHr: 85).evaluate(ctx(now));
      expect(c, isNotNull);
      expect(c!.title, 'Time to wind down');
      expect(c.body, contains('past midnight'));
      expect(c.channel, AlertChannel.retention);
      expect(c.dedupeKey, 'bedtime-2026-07-09');
    });

    test('23:30 — before the window → silent even when awake', () async {
      final now = DateTime(2026, 7, 8, 23, 30);
      expect(await rule(now: now, recentAvgHr: 85).evaluate(ctx(now)), isNull);
    });

    test('04:00 — window end is exclusive → silent', () async {
      final now = DateTime(2026, 7, 9, 4, 0);
      expect(await rule(now: now, recentAvgHr: 85).evaluate(ctx(now)), isNull);
    });

    test('no fresh HR (ring charging / disconnected) → silent', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      expect(await rule(now: now, recentAvgHr: null).evaluate(ctx(now)), isNull);
    });

    test('already asleep (HR 68 within rest+20, no steps) → silent', () async {
      final now = DateTime(2026, 7, 9, 1, 10);
      expect(await rule(now: now, recentAvgHr: 68).evaluate(ctx(now)), isNull);
    });
  });
}

class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeHrRepo extends _Fake implements HrRepository {
  _FakeHrRepo({this.avg});
  final double? avg;

  @override
  Future<double?> averageInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async =>
      avg;
}

class _FakeStepRepo extends _Fake implements StepBucketRepository {
  @override
  Future<List<StepBucket>> getForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  }) async =>
      const [];
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

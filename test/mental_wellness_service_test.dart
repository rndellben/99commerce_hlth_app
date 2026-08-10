import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/services/mental_wellness_service.dart';

/// Service-level checks for the Mental Wellness adapter using in-memory fakes
/// (the codebase tests services via injected deps, not a real DB). The engine
/// math is covered in mental_wellness_test.dart; here we verify the read →
/// adapt → persist path, the calibrating gate, and idempotent upsert.
void main() {
  const userId = 'u';
  final anchor = DateTime(2026, 7, 20);

  DailyMetrics dm(DateTime date, {double? rmssd = 50, int? rhr = 60}) =>
      DailyMetrics(
        id: 'dm-${date.toIso8601String().substring(0, 10)}',
        userId: userId,
        localDate: date,
        tzOffsetMin: 0,
        hrvRmssdMs: rmssd,
        restingHrBpm: rhr,
        computedAt: DateTime.utc(2026, 7, 20),
        algorithmVersion: 'test',
        source: DataSource.bandScheduled,
      );

  /// [n] daily rows ending on [anchor], oldest-first.
  List<DailyMetrics> days(int n) => [
        for (var i = n - 1; i >= 0; i--)
          dm(anchor.subtract(Duration(days: i))),
      ];

  MentalWellnessService build(List<DailyMetrics> rows, _FakeScoreRepo scores) =>
      MentalWellnessService(
        dailyRepo: _FakeDailyRepo(rows),
        scoreRepo: scores,
      );

  test('produces and persists a wellness Score with ≥14 days', () async {
    final scores = _FakeScoreRepo();
    final svc = build(days(20), scores);

    final s = await svc.computeForDay(userId: userId, localDate: anchor);
    expect(s, isNotNull);
    expect(s!.scoreType, ScoreType.wellness);
    expect(s.provisional, isFalse);
    expect(s.score, inInclusiveRange(0, 100));
    expect(scores.last?.id, s.id);
  });

  test('calibrating (<7 days) persists nothing and returns null', () async {
    final scores = _FakeScoreRepo();
    final svc = build(days(5), scores);

    final s = await svc.computeForDay(userId: userId, localDate: anchor);
    expect(s, isNull);
    expect(scores.last, isNull);
  });

  test('no rows → null', () async {
    final scores = _FakeScoreRepo();
    final svc = build(const [], scores);
    final s = await svc.computeForDay(userId: userId, localDate: anchor);
    expect(s, isNull);
  });

  test('recompute is idempotent (same date-keyed id)', () async {
    final scores = _FakeScoreRepo();
    final svc = build(days(20), scores);

    final s1 = await svc.computeForDay(userId: userId, localDate: anchor);
    final s2 = await svc.computeForDay(userId: userId, localDate: anchor);
    expect(s1!.id, s2!.id);
    expect(scores.upsertCount, 2);
    expect(scores.distinctIds.length, 1);
  });
}

// ── fakes ────────────────────────────────────────────────────────────────
class _FakeDailyRepo implements DailyMetricsRepository {
  _FakeDailyRepo(this._rows);
  final List<DailyMetrics> _rows;

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final out = _rows
        .where((r) =>
            !r.localDate.isBefore(fromDate) && !r.localDate.isAfter(toDate))
        .toList()
      ..sort((a, b) => a.localDate.compareTo(b.localDate));
    return out;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeScoreRepo implements ScoreRepository {
  Score? last;
  int upsertCount = 0;
  final Set<String> distinctIds = {};

  @override
  Future<Score?> getPrevious({
    required String userId,
    required ScoreType scoreType,
    required DateTime beforeDate,
  }) async =>
      null;

  @override
  Future<void> upsert(Score score) async {
    last = score;
    upsertCount++;
    distinctIds.add(score.id);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

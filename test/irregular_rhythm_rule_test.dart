import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/irregular_rhythm_rule.dart';

void main() {
  const userId = 'u1';
  final now = DateTime.utc(2026, 6, 22, 12);

  // Days are offsets back from `now`. cov/ectopic null = a day with no
  // rhythm assessment (capture didn't pass the gate).
  DailyMetrics dm(int daysAgo, {double? cov, double? ectopic}) {
    final date = DateTime(2026, 6, 22).subtract(Duration(days: daysAgo));
    return DailyMetrics(
      id: 'd$daysAgo',
      userId: userId,
      localDate: date,
      tzOffsetMin: 0,
      rrIrregularityPct: cov,
      ectopicBeatPct: ectopic,
      computedAt: now,
      algorithmVersion: 'test',
      source: DataSource.appRecomputed,
    );
  }

  Future<AlertCandidate?> run(List<DailyMetrics> rows) {
    final rule = IrregularRhythmRule(dailyRepo: _FakeDailyRepo(rows));
    return rule.evaluate(AlertContext(userId: userId, now: now));
  }

  test('fires on a sustained, current pattern (≥3 flagged, recent)', () async {
    final c = await run([
      dm(0, cov: 25, ectopic: 35), // flagged + recent
      dm(1, cov: 22, ectopic: 32), // flagged
      dm(2, cov: 28, ectopic: 40), // flagged
      dm(5, cov: 8, ectopic: 10), // normal
      dm(7, cov: 7, ectopic: 9), // normal
    ]);
    expect(c, isNotNull);
    expect(c!.dedupeKey, startsWith('irregular_rhythm-'));
    expect(c.payload!['flaggedDays'], 3);
    // Wellness framing only — never a diagnosis term.
    final text = '${c.title} ${c.body}'.toLowerCase();
    expect(text.contains('afib'), isFalse);
    expect(text.contains('fibrillation'), isFalse);
    expect(text.contains('diagnosis'), isTrue); // "isn't a diagnosis"
  });

  test('does not fire on a thin history (< minDataDays assessed)', () async {
    final c = await run([
      dm(0, cov: 25, ectopic: 35),
      dm(1, cov: 22, ectopic: 32),
      dm(2, cov: 28, ectopic: 40),
    ]); // 3 assessed < 4
    expect(c, isNull);
  });

  test('does not fire with too few flagged days', () async {
    final c = await run([
      dm(0, cov: 25, ectopic: 35), // flagged
      dm(1, cov: 24, ectopic: 33), // flagged
      dm(2, cov: 8, ectopic: 10),
      dm(4, cov: 7, ectopic: 9),
      dm(6, cov: 9, ectopic: 12),
    ]); // only 2 flagged < 3
    expect(c, isNull);
  });

  test('requires BOTH metrics elevated — high CoV alone does not flag',
      () async {
    final c = await run([
      dm(0, cov: 30, ectopic: 12), // high CoV, normal ectopic → not flagged
      dm(1, cov: 28, ectopic: 14),
      dm(2, cov: 26, ectopic: 11),
      dm(4, cov: 25, ectopic: 13),
      dm(6, cov: 22, ectopic: 10),
    ]);
    expect(c, isNull);
  });

  test('does not fire on a stale pattern (no flagged day in recency window)',
      () async {
    final c = await run([
      dm(7, cov: 25, ectopic: 35), // flagged but old
      dm(8, cov: 24, ectopic: 33), // flagged but old
      dm(9, cov: 28, ectopic: 40), // flagged but old
      dm(0, cov: 8, ectopic: 10), // recent, normal
      dm(1, cov: 7, ectopic: 9), // recent, normal
    ]);
    expect(c, isNull);
  });
}

class _FakeDailyRepo implements DailyMetricsRepository {
  _FakeDailyRepo(this.rows);
  final List<DailyMetrics> rows;

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async =>
      rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

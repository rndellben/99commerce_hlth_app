import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/services/ppg_analysis_service.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';

/// The rest gate on the automatic daily PPG capture: an attempt is only spent
/// when recent HR sits near the user's resting baseline, so the day's limited
/// attempts aren't wasted on active periods (where RSA can't be read) and
/// survive to a quiet rest / sleep window.
void main() {
  ScheduledPpgCaptureService build({
    required double? recentAvgHr,
    required List<int?> bankedRestingHr,
  }) {
    return ScheduledPpgCaptureService(
      ble: _FakeBle(),
      analysis: _FakeAnalysis(),
      dailyRepo: _FakeDailyRepo(bankedRestingHr),
      hrRepo: _FakeHrRepo(recentAvgHr),
    );
  }

  group('isAtRest', () {
    test('no fresh HR in the window → not at rest (skip, cannot confirm)',
        () async {
      final svc = build(recentAvgHr: null, bankedRestingHr: [60]);
      expect(await svc.isAtRest(userId: 'u'), isFalse);
    });

    test('recent HR near baseline → at rest', () async {
      // 62 vs resting 60 → within the 15 bpm margin (≤ 75).
      final svc = build(recentAvgHr: 62, bankedRestingHr: [60]);
      expect(await svc.isAtRest(userId: 'u'), isTrue);
    });

    test('recent HR just inside the margin → at rest', () async {
      // 75 vs resting 60 + 15 = 75 (boundary, inclusive).
      final svc = build(recentAvgHr: 75, bankedRestingHr: [60]);
      expect(await svc.isAtRest(userId: 'u'), isTrue);
    });

    test('elevated HR (active) → not at rest', () async {
      // 110 vs resting 60 → 50 over baseline, well past the margin.
      final svc = build(recentAvgHr: 110, bankedRestingHr: [60]);
      expect(await svc.isAtRest(userId: 'u'), isFalse);
    });

    test('no banked baseline → falls back to default resting (70)', () async {
      // 80 vs default 70 + 15 = 85 → at rest.
      final atRest = build(recentAvgHr: 80, bankedRestingHr: <int?>[]);
      expect(await atRest.isAtRest(userId: 'u'), isTrue);
      // 90 vs 85 → not at rest.
      final active = build(recentAvgHr: 90, bankedRestingHr: <int?>[]);
      expect(await active.isAtRest(userId: 'u'), isFalse);
    });

    test('uses the freshest banked baseline (most recent day wins)', () async {
      // getInRange returns ascending by date; the reference must be the LAST
      // non-null (65), not the older 55. 78 ≤ 65+15=80 → at rest.
      final svc = build(recentAvgHr: 78, bankedRestingHr: [55, 65]);
      expect(await svc.isAtRest(userId: 'u'), isTrue);
    });

    test('skips null baselines, takes the freshest real one', () async {
      // Rows: [58, null] → freshest real baseline is 58. 78 > 58+15=73 → not
      // at rest (proves a trailing null does not mask the real baseline).
      final svc = build(recentAvgHr: 78, bankedRestingHr: [58, null]);
      expect(await svc.isAtRest(userId: 'u'), isFalse);
    });
  });
}

class _FakeHrRepo implements HrRepository {
  _FakeHrRepo(this._avg);
  final double? _avg;

  @override
  Future<double?> averageInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async =>
      _avg;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeDailyRepo implements DailyMetricsRepository {
  _FakeDailyRepo(this._restingHr);
  final List<int?> _restingHr;

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    // Ascending by date, mirroring the real repo.
    var day = DateTime(2026, 6, 1);
    return [
      for (final r in _restingHr)
        DailyMetrics(
          id: 'm-${day.day}',
          userId: userId,
          localDate: day = day.add(const Duration(days: 1)),
          tzOffsetMin: 480,
          computedAt: DateTime(2026, 6, 1),
          algorithmVersion: 'test',
          source: DataSource.appRecomputed,
          restingHrBpm: r,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBle implements BleService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAnalysis implements PpgAnalysisService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

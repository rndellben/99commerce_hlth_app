import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';

/// Unit tests for the sleep-window HRV gating: only samples inside
/// [bedtime, wake) count, the result is their median, and an empty window
/// returns null (so the engine leaves HRV absent rather than fabricating).
void main() {
  HrvSample hrv(DateTime t, double rmssd, {double? sdnn}) => HrvSample(
        id: 's-${t.millisecondsSinceEpoch}',
        userId: 'u',
        deviceId: 'd',
        capturedAt: t,
        tzOffsetMin: 0,
        rmssdMs: rmssd,
        sdnnMs: sdnn,
        source: DataSource.bandScheduled,
      );

  // Sleep window: 23:00 → 07:00 UTC.
  final start = DateTime.utc(2026, 6, 24, 23);
  final end = DateTime.utc(2026, 6, 25, 7);

  test('uses only in-window samples and returns their median', () {
    final samples = [
      hrv(DateTime.utc(2026, 6, 24, 14), 20), // afternoon — excluded
      hrv(DateTime.utc(2026, 6, 24, 23, 30), 40), // in window
      hrv(DateTime.utc(2026, 6, 25, 2), 50), // in window
      hrv(DateTime.utc(2026, 6, 25, 5), 60), // in window
      hrv(DateTime.utc(2026, 6, 25, 12), 200), // next afternoon — excluded
    ];
    // In-window RMSSD = [40, 50, 60] → median 50.
    expect(
      DailyAggregator.sleepWindowMedianRmssd(samples, start, end),
      50,
    );
  });

  test('daytime-only samples yield null (HRV stays absent, not fabricated)', () {
    final samples = [
      hrv(DateTime.utc(2026, 6, 24, 14), 25),
      hrv(DateTime.utc(2026, 6, 25, 13), 30),
    ];
    expect(DailyAggregator.sleepWindowMedianRmssd(samples, start, end), isNull);
  });

  test('SDNN median ignores samples missing SDNN', () {
    final samples = [
      hrv(DateTime.utc(2026, 6, 25, 1), 40, sdnn: 55),
      hrv(DateTime.utc(2026, 6, 25, 3), 45), // no SDNN — skipped
      hrv(DateTime.utc(2026, 6, 25, 5), 50, sdnn: 65),
    ];
    // SDNN in window = [55, 65] → median 60.
    expect(DailyAggregator.sleepWindowMedianSdnn(samples, start, end), 60);
  });

  test('window is half-open: start included, end excluded', () {
    final samples = [
      hrv(start, 41), // exactly bedtime — included
      hrv(end, 99), // exactly wake — excluded
    ];
    expect(DailyAggregator.sleepWindowMedianRmssd(samples, start, end), 41);
  });
}

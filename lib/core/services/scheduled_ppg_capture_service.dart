import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/services/ppg_analysis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Step 3: headless once-a-day PPG capture so resting respiratory + HRV
/// populate the home cards without the user tapping Analyze.
///
/// The band doesn't stream PPG continuously — it only emits raw samples
/// during a `startMeasureHrRaw` window. So this drives a capture, buffers
/// the (ppg_count, green) stream exactly like the BLE Debug screen, runs it
/// through the shared [PpgAnalysisService], and persists **only if the
/// capture clears the quality gate** (otherwise the card keeps its last
/// good value rather than showing a junk reading).
///
/// Duration is 3 min: Ryan's 2026-06-17 guidance was 1-5 min ("5 is best")
/// for good metrics — the longer tachogram gives RSA/HRV far more beats and
/// cleaning headroom than the 90 s debug capture. Bump toward 5 min if the
/// daily battery cost proves acceptable.
class ScheduledPpgCaptureService {
  ScheduledPpgCaptureService({
    required this.ble,
    required this.analysis,
    required this.dailyRepo,
    this.captureDuration = const Duration(seconds: 180),
  });

  final BleService ble;
  final PpgAnalysisService analysis;
  final DailyMetricsRepository dailyRepo;
  final Duration captureDuration;
  final _uuid = const Uuid();

  bool _inFlight = false;
  bool get isCapturing => _inFlight;

  /// Broadcasts capture start (true) / end (false) so the UI can show a
  /// "Measuring…" state on the respiratory card while a capture is running.
  final _capturing = StreamController<bool>.broadcast();
  Stream<bool> get capturingStream => _capturing.stream;

  static const _kLastCaptureDateKey = 'scheduled_ppg_last_capture_date';
  static const _kAttemptDateKey = 'scheduled_ppg_attempt_date';
  static const _kAttemptCountKey = 'scheduled_ppg_attempt_count';

  /// Max capture attempts per day before giving up. Respiratory needs ONE
  /// clean capture; on a flaky-signal day we retry across ticks rather than
  /// abandoning the card after a single rejected attempt — but cap the count
  /// so a persistently bad day can't drain the battery with endless 3-min
  /// captures. At a 10-30 min tick this spans a good part of the day.
  static const maxDailyAttempts = 8;

  /// Run on the periodic tick until ONE capture clears the quality gate that
  /// day. Returns the result when a capture actually ran, or null if skipped
  /// (already succeeded today / attempt cap reached / not connected / one
  /// already in flight).
  ///
  /// Why retry: respiratory is derived from an active PPG capture, and on
  /// this sensor a single capture is often rejected (motion, BLE loss,
  /// elevated HR). Marking the day "done" on a rejected capture left the
  /// card blank all day. Now we only mark the day done on a PASS, so later
  /// ticks keep trying until a clean reading lands — then stop for the day.
  Future<PpgAnalysisResult?> maybeRunDaily({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _localDateKey(DateTime.now());

    // Already have a passing capture today → nothing to do.
    if (prefs.getString(_kLastCaptureDateKey) == today) return null;

    // Bound the number of attempts per day.
    final attempts =
        prefs.getString(_kAttemptDateKey) == today
            ? (prefs.getInt(_kAttemptCountKey) ?? 0)
            : 0;
    if (attempts >= maxDailyAttempts) return null;

    final result = await captureAndPersist(userId: userId);
    // result == null means the capture never ran (not connected / too few
    // samples) — don't burn an attempt on it.
    if (result == null) return null;

    await prefs.setString(_kAttemptDateKey, today);
    await prefs.setInt(_kAttemptCountKey, attempts + 1);

    // End the day's retries only once we actually have the resting
    // respiratory rate — the value the Sleep card needs. A gate PASS alone no
    // longer implies it: with the band's realtime HR often unavailable the HR
    // cross-check is skipped, so a cardiac-clean capture passes the gate while
    // RSA (respiratory) can still be too weak to yield a peak — typical of
    // awake, seated daytime captures. Marking the day "done" on such a capture
    // left the card blank all day. HRV is still banked by captureAndPersist on
    // every passing capture; the retries (bounded by maxDailyAttempts) keep
    // trying for a rest window where RSA is strong enough to read.
    if (result.passedQualityGate && result.respRateBpm != null) {
      await prefs.setString(_kLastCaptureDateKey, today);
    }
    return result;
  }

  /// Capture [captureDuration] of PPG, analyse it, and persist resting
  /// respiratory + HRV to today's daily_metrics IF it clears the quality
  /// gate. Always attempts (no daily gate) — this is what the debug
  /// "Capture Now" button calls. Returns null when not connected or a
  /// capture is already running.
  Future<PpgAnalysisResult?> captureAndPersist({required String userId}) async {
    if (_inFlight) return null;
    if (ble.currentConnectionState != BleConnectionState.connected) return null;
    _inFlight = true;
    _capturing.add(true);

    final counts = <int>[];
    final greens = <double>[];
    var greenZero = 0;
    int? bandHr;
    StreamSubscription<List<Map<String, dynamic>>>? ppgSub;
    StreamSubscription<int>? hrSub;
    try {
      ppgSub = ble.rawPpgEvent.listen((samples) {
        for (final s in samples) {
          final c = s['ppg_count'];
          final g = s['green'];
          final gv = (g is num) ? g.toDouble() : 0.0;
          if (c is num) {
            counts.add(c.toInt());
            greens.add(gv);
          }
          if (gv <= 0) greenZero++;
        }
      });
      // Capture the band's own HR during the window for the gate's
      // cross-check (passive notifications keep arriving during raw mode).
      hrSub = ble.realtimeHeartRate.listen((hr) => bandHr = hr);

      final secs = captureDuration.inSeconds;
      await ble.startMeasureHrRaw(durationSec: secs);
      await Future<void>.delayed(captureDuration + const Duration(seconds: 1));
      await ble.stopMeasure();

      if (counts.length < 100) return null; // band streamed too little

      final result = analysis.analyze(
        counts: counts,
        greens: greens,
        greenZeroCount: greenZero,
        durationSec: secs.toDouble(),
        bandHr: bandHr,
      );
      if (result.passedQualityGate) {
        await _persist(userId: userId, result: result);
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      await ppgSub?.cancel();
      await hrSub?.cancel();
      _inFlight = false;
      _capturing.add(false);
    }
  }

  /// Merge resting respiratory + HRV into today's daily_metrics without
  /// clobbering other columns. Null fields keep whatever's already there.
  Future<void> _persist({
    required String userId,
    required PpgAnalysisResult result,
  }) async {
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    final nowUtc = now.toUtc();
    final existing =
        await dailyRepo.getForDay(userId: userId, localDate: localDate);
    final merged = (existing ??
            DailyMetrics(
              id: _uuid.v4(),
              userId: userId,
              localDate: localDate,
              tzOffsetMin: now.timeZoneOffset.inMinutes,
              computedAt: nowUtc,
              algorithmVersion: 'scheduled-ppg-v1',
              source: DataSource.appRecomputed,
            ))
        .copyWith(
      restingRespRateBpm:
          result.respRateBpm ?? existing?.restingRespRateBpm,
      hrvRmssdMs: result.hrvRmssdMs ?? existing?.hrvRmssdMs,
      hrvSdnnMs: result.hrvSdnnMs ?? existing?.hrvSdnnMs,
      rrIrregularityPct:
          result.rrIrregularityPct ?? existing?.rrIrregularityPct,
      ectopicBeatPct: result.ectopicBeatPct ?? existing?.ectopicBeatPct,
      computedAt: nowUtc,
    );
    await dailyRepo.upsert(merged);
  }

  String _localDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final scheduledPpgCaptureServiceProvider =
    Provider<ScheduledPpgCaptureService>((ref) {
  return ScheduledPpgCaptureService(
    ble: ref.watch(bleServiceProvider),
    analysis: ref.watch(ppgAnalysisServiceProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});

/// True while a respiratory PPG capture is running — drives the home
/// respiratory card's "Measuring…" state. Defaults to false until the first
/// event.
final ppgCapturingProvider = StreamProvider<bool>((ref) {
  return ref.watch(scheduledPpgCaptureServiceProvider).capturingStream;
});

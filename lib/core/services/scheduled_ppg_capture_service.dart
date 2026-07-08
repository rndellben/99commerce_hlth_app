import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
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
    required this.hrRepo,
    this.captureDuration = const Duration(seconds: 180),
  });

  final BleService ble;
  final PpgAnalysisService analysis;
  final DailyMetricsRepository dailyRepo;
  final HrRepository hrRepo;
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

  /// Rest gate: only spend a daily attempt when recent HR sits within this
  /// many bpm of the user's resting baseline. Respiratory (RSA) is only
  /// readable when the heart is near rest — an elevated/active capture can't
  /// produce a breathing peak and would just waste the day's limited attempts.
  /// 15 bpm admits calm sitting and all of sleep while rejecting walks,
  /// exercise and acute stress (typically resting + 30-60 bpm).
  static const _restMarginBpm = 15.0;

  /// Fallback resting HR when the user has no banked `restingHrBpm` yet (first
  /// days of wear). 70 + margin ≈ an 85 bpm ceiling — a reasonable "not active"
  /// bound until a personal baseline lands.
  static const _defaultRestingBpm = 70.0;

  /// How far back to look for a fresh HR reading to judge "at rest now". When
  /// connected the band syncs scheduled HR every tick, so a 30-min window
  /// almost always has samples; an empty window means we can't confirm rest,
  /// so we skip (without burning an attempt) rather than capture blind.
  static const _recentHrWindow = Duration(minutes: 30);

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
  Future<PpgAnalysisResult?> maybeRunDaily({
    required String userId,
    bool asleep = false,
  }) async {
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

    // Only spend an attempt when the user appears to be at rest — RSA is only
    // readable near resting HR, so an active/elevated capture can't yield a
    // respiratory number and would just burn the day's limited attempts. This
    // concentrates the (bounded) attempts on quiet rest and sleep, where the
    // breathing peak is strong. Skips WITHOUT burning an attempt (mirrors the
    // not-connected skip), so the budget survives to the sleep window.
    //
    // A caller-supplied asleep verdict (SleepOnsetDetector: settled HR + zero
    // steps) is strictly stronger evidence of rest than the +15 bpm gate, so
    // it passes directly — sleep is the capture window RSA likes best.
    if (!asleep && !await isAtRest(userId: userId)) return null;

    if (asleep) Breadcrumbs.log('ppg: capture attempt while ASLEEP');
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

  /// True when the user's recent HR is close enough to their resting baseline
  /// that a PPG capture could plausibly carry a readable respiratory (RSA)
  /// rhythm. Returns false when HR is elevated (active) OR when there's no
  /// fresh HR to judge from — in both cases capturing would likely waste an
  /// attempt, so we wait for a calmer tick.
  @visibleForTesting
  Future<bool> isAtRest({required String userId}) async {
    final nowUtc = DateTime.now().toUtc();
    final recentAvg = await hrRepo.averageInRange(
      userId: userId,
      from: nowUtc.subtract(_recentHrWindow),
      to: nowUtc,
    );
    if (recentAvg == null) {
      debugPrint('[ppg] daily capture skipped: no HR in last '
          '${_recentHrWindow.inMinutes}m — cannot confirm rest');
      return false;
    }
    final resting = await _restingReferenceBpm(userId);
    final atRest = recentAvg <= resting + _restMarginBpm;
    if (!atRest) {
      debugPrint('[ppg] daily capture skipped: HR '
          '${recentAvg.toStringAsFixed(0)} > rest '
          '${resting.toStringAsFixed(0)}+$_restMarginBpm — not at rest');
    }
    return atRest;
  }

  /// The user's resting-HR reference: the most recent banked `restingHrBpm`
  /// within the last 14 days, or [_defaultRestingBpm] if none exists yet.
  Future<double> _restingReferenceBpm(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: today.subtract(const Duration(days: 14)),
      toDate: today,
    );
    // getInRange is ascending by date — walk back for the freshest baseline.
    for (final m in rows.reversed) {
      final r = m.restingHrBpm;
      if (r != null && r > 0) return r.toDouble();
    }
    return _defaultRestingBpm;
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
      // HRV: EXISTING wins. The aggregator's sleep-window median is the
      // authoritative daily HRV (it feeds Recovery and the Sleep screen);
      // a capture's RMSSD is only a fallback filler for days where the band
      // served no sleep HRV. Capture-wins here let one awake capture (which
      // can carry inflated RMSSD — 290 ms seen 2026-07-07) clobber a clean
      // overnight median. The aggregator independently prefers its own sleep
      // median over whatever a capture left, so ordering stays correct.
      hrvRmssdMs: existing?.hrvRmssdMs ?? result.hrvRmssdMs,
      hrvSdnnMs: existing?.hrvSdnnMs ?? result.hrvSdnnMs,
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
    hrRepo: ref.watch(hrRepositoryProvider),
  );
});

/// True while a respiratory PPG capture is running — drives the home
/// respiratory card's "Measuring…" state. Defaults to false until the first
/// event.
final ppgCapturingProvider = StreamProvider<bool>((ref) {
  return ref.watch(scheduledPpgCaptureServiceProvider).capturingStream;
});

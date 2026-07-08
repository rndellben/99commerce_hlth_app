import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// App-driven nightly resting BP.
///
/// The H59 has no retrievable scheduled-BP history — its `getBpDay` times
/// out and `getBpHistory` returns hourly HR, not BP (verified on-device
/// 2026-06-25). The only working BP path is the on-demand active
/// measurement (`startBpMeasurement`, ~30 s). So instead of relying on the
/// band's scheduler, this fires our own measurement during the night and
/// persists the result like any other `bp_reading` — the daily aggregator
/// then rolls it into the sleep-window BP on the sleep screen.
///
/// Triggered from the periodic sync tick (`PeriodicSyncCoordinator`), which
/// already holds a BLE link overnight. v1 takes ONE resting reading per
/// night: it fires on the first connected tick inside the night window and
/// stops once a reading converges.
///
/// Firing is gated on BOTH:
///  * the night window (default 23:00–11:00) — bounds which calendar night a
///    reading belongs to (see [nightKey]); the 11:00 end covers late sleepers
///    (verified 2026-07-07: user sleeps 03:37–12:52), AND
///  * the caller's live `asleep` verdict ([SleepOnsetDetector]) — the band's
///    sleep classification is retrospective, so the detector approximates
///    "asleep now" from settled HR + zero steps. Without this gate the first
///    tick after 23:00 fired on an awake, moving user and burned the night's
///    attempt cap on motion-garbage readings before sleep even began
///    (Ryan 2026-06-23: "when sleep is triggered, we trigger these things").
///
/// A non-converged measurement (ring off, motion) returns 0/0 and is
/// discarded, so the next asleep tick retries until a clean reading lands or
/// the per-night attempt cap is hit.
class NightlyBpCaptureService {
  NightlyBpCaptureService({
    required this.ble,
    required this.bpRepo,
    required this.deviceRepo,
    this.windowStartHour = 23,
    this.windowEndHour = 11,
  });

  final BleService ble;
  final BpRepository bpRepo;
  final DeviceRepository deviceRepo;

  /// Night window in local hours: `[windowStartHour, 24) ∪ [0, windowEndHour)`.
  /// Defaults to 23:00–11:00. The sleep-onset gate does the real targeting;
  /// this only bounds the span and names the night for the once-per-night key.
  final int windowStartHour;
  final int windowEndHour;

  static const _uuid = Uuid();
  static const _algorithmVersion = 'nightly-bp-v1';

  static const _kLastNightKey = 'nightly_bp_last_success_night';
  static const _kAttemptNightKey = 'nightly_bp_attempt_night';
  static const _kAttemptCountKey = 'nightly_bp_attempt_count';

  /// Max measurements per night before giving up. Each is ~30 s of active
  /// LEDs; at a 10-min tick across an 8 h window there are ~48 ticks, so the
  /// cap stops a ring-off / non-converging night from firing on every one.
  static const maxNightlyAttempts = 6;

  bool _inFlight = false;
  bool get isMeasuring => _inFlight;

  /// Run on the periodic tick. Takes one resting BP reading per night while
  /// inside the night window AND [asleep], retrying across asleep ticks until
  /// one converges. Returns the reading when one was persisted, else null
  /// (outside the window / awake / already done tonight / cap reached / not
  /// connected / didn't converge).
  Future<({int sbp, int dbp})?> maybeRunNightly({
    required String userId,
    bool asleep = false,
  }) async {
    if (_inFlight) return null;
    if (ble.currentConnectionState != BleConnectionState.connected) return null;

    final nightKey = nightKeyFor(DateTime.now());
    if (nightKey == null) return null; // daytime — outside the window

    // Sleep-onset gate: an awake tick never spends a nightly attempt — the
    // reading we want is a SLEEPING BP, and awake/moving attempts were what
    // burned the cap before sleep began. Skipping costs nothing; the next
    // asleep tick tries again.
    if (!asleep) return null;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLastNightKey) == nightKey) return null; // got tonight's

    final attempts = prefs.getString(_kAttemptNightKey) == nightKey
        ? (prefs.getInt(_kAttemptCountKey) ?? 0)
        : 0;
    if (attempts >= maxNightlyAttempts) return null;

    // Burn an attempt up front — a non-converging (ring-off) night should
    // cap out rather than fire a 30 s measurement on every tick.
    await prefs.setString(_kAttemptNightKey, nightKey);
    await prefs.setInt(_kAttemptCountKey, attempts + 1);

    Breadcrumbs.log('bp: night attempt ${attempts + 1}/$maxNightlyAttempts');
    final result = await captureAndPersist(userId: userId);
    if (result != null) {
      // Converged — that's tonight's resting BP; stop retrying this night.
      await prefs.setString(_kLastNightKey, nightKey);
      Breadcrumbs.log('bp: converged ${result.sbp}/${result.dbp} — night done');
    } else {
      Breadcrumbs.log('bp: attempt did not converge');
    }
    return result;
  }

  /// Fire one active BP measurement now and persist it if it converges.
  /// Always attempts (no window/gate) — this is what the debug button calls.
  /// Returns the reading, or null when not connected, no active device, a
  /// measurement is already in flight, or the band didn't converge.
  Future<({int sbp, int dbp})?> captureAndPersist({
    required String userId,
  }) async {
    if (_inFlight) return null;
    if (ble.currentConnectionState != BleConnectionState.connected) return null;
    final device = await deviceRepo.getActiveForUser(userId);
    if (device == null) return null;

    _inFlight = true;
    try {
      final r = await ble.startBpMeasurement();
      final sbp = (r['sbp'] as num?)?.toInt() ?? 0;
      final dbp = (r['dbp'] as num?)?.toInt() ?? 0;
      final hr = (r['hr'] as num?)?.toInt() ?? 0;
      if (sbp <= 0 || dbp <= 0) return null; // didn't converge (ring off/motion)

      final now = DateTime.now();
      await bpRepo.insert(BpReading(
        id: _uuid.v4(),
        userId: userId,
        deviceId: device.id,
        capturedAt: now.toUtc(),
        tzOffsetMin: now.timeZoneOffset.inMinutes,
        systolicMmhg: sbp,
        diastolicMmhg: dbp,
        pulseBpm: hr > 0 ? hr : null,
        derivation: BpDerivation.bandSensor,
        source: DataSource.bandScheduled,
        algorithmVersion: _algorithmVersion,
      ));
      return (sbp: sbp, dbp: dbp);
    } catch (_) {
      try {
        await ble.stopBpMeasurement();
      } catch (_) {}
      return null;
    } finally {
      _inFlight = false;
    }
  }

  /// The "night key" for [now] under this service's window, or null if
  /// [now] is outside it. See [nightKey].
  String? nightKeyFor(DateTime now) => nightKey(
        now,
        startHour: windowStartHour,
        endHour: windowEndHour,
      );

  /// The "night key" for [now] if it's inside the window, else null. The key
  /// is the date the window opened, so for an overnight window 23:30 tonight
  /// and 02:00 tomorrow map to the same night (a single reading spans
  /// midnight). Static + pure so the windowing is unit-testable without live
  /// deps.
  ///
  /// Handles both shapes:
  /// * overnight (`startHour > endHour`, e.g. 23→7): `[startHour,24) ∪ [0,endHour)`
  /// * same-day (`startHour <= endHour`, e.g. 1→5): `[startHour, endHour)`
  static String? nightKey(
    DateTime now, {
    required int startHour,
    required int endHour,
  }) {
    final h = now.hour;
    if (startHour > endHour) {
      // Overnight window that wraps midnight.
      if (h >= startHour) return _dateKey(now); // evening side — opened today
      if (h < endHour) {
        // morning side — window opened the previous calendar day
        return _dateKey(now.subtract(const Duration(days: 1)));
      }
      return null;
    }
    // Same-day window: [startHour, endHour).
    if (h >= startHour && h < endHour) return _dateKey(now);
    return null;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final nightlyBpCaptureServiceProvider =
    Provider<NightlyBpCaptureService>((ref) {
  return NightlyBpCaptureService(
    ble: ref.watch(bleServiceProvider),
    bpRepo: ref.watch(bpRepositoryProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
  );
});

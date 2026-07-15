import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/processing/fall_detector.dart';

/// HLT-5: the background fall sweep. Opens a short PPG capture window,
/// collects accel triples from the realtime stream, then evaluates the
/// three-window state machine across the buffered samples.
///
/// **H59 constraint:** raw accelerometer data is only emitted while
/// `startMeasureHrRaw` is running. We open the smallest window we can
/// (default 30 s) to keep battery impact low — that's ~1.7% duty
/// cycle when the periodic scheduler fires every 30 minutes.
///
/// Split out of `PeriodicSyncCoordinator` so the capture + calibration +
/// detection pipeline is one testable unit and the coordinator stays pure
/// sequencing.
class FallSweepService {
  FallSweepService({
    required this.ble,
    this.sweepDuration = const Duration(seconds: 30),
    FallDetector? fallDetector,
  }) : _fallDetector = fallDetector ?? const FallDetector();

  final BleService ble;
  final Duration sweepDuration;
  final FallDetector _fallDetector;

  Future<FallSweepResult> run() async {
    final startedAt = DateTime.now().toUtc();
    final durationS = sweepDuration.inSeconds;
    final accelX = <int>[];
    final accelY = <int>[];
    final accelZ = <int>[];

    StreamSubscription<List<Map<String, dynamic>>>? sub;
    try {
      sub = ble.rawPpgEvent.listen((samples) {
        for (final s in samples) {
          final ax = s['accel_x'];
          final ay = s['accel_y'];
          final az = s['accel_z'];
          if (ax is num && ay is num && az is num) {
            accelX.add(ax.toInt());
            accelY.add(ay.toInt());
            accelZ.add(az.toInt());
          }
        }
      });

      await ble.startMeasureHrRaw(durationSec: durationS);
      // Add a small grace period so the band's final packets land in our
      // buffer before we cancel the listener.
      await Future<void>.delayed(Duration(seconds: durationS + 1));
    } catch (e) {
      await sub?.cancel();
      try {
        await ble.stopMeasure();
      } catch (_) {}
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'capture failed: $e',
      );
    }
    await sub.cancel();
    try {
      await ble.stopMeasure();
    } catch (_) {}

    if (accelX.length < 50) {
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'too few accel samples (${accelX.length})',
      );
    }

    // Calibrate the local "1 g" reference from the median magnitude of
    // the captured window. Using median (not mean) so a real impact
    // doesn't pull the reference up and dilute the freefall threshold.
    final magsRaw = List<double>.generate(accelX.length, (i) {
      final x = accelX[i].toDouble();
      final y = accelY[i].toDouble();
      final z = accelZ[i].toDouble();
      return math.sqrt(x * x + y * y + z * z);
    });
    final sortedMags = List<double>.from(magsRaw)..sort();
    final oneGRaw = sortedMags[sortedMags.length ~/ 2];
    if (oneGRaw <= 0) {
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'calibration returned zero — accel stream was flat',
      );
    }

    final xMg = accelX
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);
    final yMg = accelY
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);
    final zMg = accelZ
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);

    final fsHz = accelX.length / durationS;
    final events = _fallDetector.detect(
      accelXMilliG: xMg,
      accelYMilliG: yMg,
      accelZMilliG: zMg,
      samplingRateHz: fsHz,
    );

    return FallSweepResult(
      sweptAt: startedAt,
      captureDurationS: durationS,
      sampleCount: accelX.length,
      events: events,
      calibratedOneGRaw: oneGRaw,
    );
  }
}

final fallSweepServiceProvider = Provider<FallSweepService>((ref) {
  return FallSweepService(ble: ref.watch(bleServiceProvider));
});

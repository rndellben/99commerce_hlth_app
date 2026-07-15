/// Pure value types for the BLE layer — no platform channels, no I/O.
///
/// Split from `ble_service.dart` so consumers that only need a type (a
/// connection-state enum for a status chip, a sport-type constant for a
/// label) don't have to import the whole transport class.
library;

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({required this.id, required this.name, required this.rssi});
}

class BleException implements Exception {
  final String message;
  BleException(this.message);

  @override
  String toString() => 'BleException: $message';
}

/// SDK byte values for the 8 curated exercise types per Ryan's
/// 2026-06-17 call ("eight things people actually do"). Mapping comes
/// from sdk_ring.pdf §2.3.10 / OdmSportPlusExerciseModelType.
abstract final class SportTypes {
  static const running = 7;
  static const walking = 4;
  static const cycling = 9;
  static const hiking = 8;
  static const rowing = 27;
  static const elliptical = 26;
  static const yoga = 22;
  static const strength = 88; // Indoor sports - strength training
}

/// Native ack for a `PhoneSportReq.getSportStatus(...)` call. The band
/// returns its current GPS status (0=closed, 6=ready, etc.) and the
/// timestamp it actually applied — useful for reconciling drift between
/// the phone's clock and the band's.
class SportSessionAck {
  const SportSessionAck({
    required this.status,
    required this.sportType,
    required this.gpsStatus,
    required this.timestamp,
  });

  /// 1=Start, 2=Pause, 3=Continue, 4=End — echo of the request status.
  final int status;
  final int sportType;
  final int gpsStatus;
  final int timestamp;
}

/// Workout summary returned by `SportPlusHandle.syncSportPlus(...)`.
/// Field semantics from sdk_ring.pdf "Synchronous training records" —
/// distance is meters, speed is cm/s, calories are "small calories" (the
/// SDK's term; treat as kcal for display, divide by 1000 if values look
/// inflated on real hardware).
class SportSessionSummary {
  const SportSessionSummary({
    required this.sportType,
    required this.startTimeUnixSec,
    required this.trainingStartTime,
    required this.durationSec,
    required this.distanceM,
    required this.calories,
    required this.avgSpeedCmS,
    required this.maxSpeedCmS,
    required this.avgHr,
    required this.minHr,
    required this.maxHr,
    required this.elevationCm,
    required this.uphillCm,
    required this.downhillCm,
    required this.stepRate,
    required this.steps,
    required this.locationCount,
  });

  factory SportSessionSummary.fromMap(Map<String, dynamic> m) =>
      SportSessionSummary(
        sportType: (m['sportType'] as num).toInt(),
        startTimeUnixSec: (m['startTime'] as num).toInt(),
        trainingStartTime: m['trainingStartTime'] as String? ?? '',
        durationSec: (m['duration'] as num).toInt(),
        distanceM: (m['distance'] as num).toInt(),
        calories: (m['calories'] as num).toDouble(),
        avgSpeedCmS: (m['speedAvg'] as num).toInt(),
        maxSpeedCmS: (m['speedMax'] as num).toInt(),
        avgHr: (m['rateAvg'] as num).toInt(),
        minHr: (m['rateMin'] as num).toInt(),
        maxHr: (m['rateMax'] as num).toInt(),
        elevationCm: (m['elevation'] as num).toInt(),
        uphillCm: (m['uphill'] as num).toInt(),
        downhillCm: (m['downhill'] as num).toInt(),
        stepRate: (m['stepRate'] as num).toInt(),
        steps: (m['steps'] as num).toInt(),
        locationCount: (m['locationCount'] as num).toInt(),
      );

  final int sportType;
  final int startTimeUnixSec;
  final String trainingStartTime;
  final int durationSec;
  final int distanceM;
  final double calories;
  final int avgSpeedCmS;
  final int maxSpeedCmS;
  final int avgHr;
  final int minHr;
  final int maxHr;
  final int elevationCm;
  final int uphillCm;
  final int downhillCm;
  final int stepRate;
  final int steps;
  final int locationCount;
}

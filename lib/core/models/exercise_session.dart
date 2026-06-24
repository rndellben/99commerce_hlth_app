import 'package:hlth_app/core/database/enums.dart';

/// One completed workout pulled from the band's sport-mode state machine.
/// See `ExerciseSessions` Drift table for the canonical column list.
class ExerciseSession {
  const ExerciseSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.sportType,
    required this.startedAt,
    required this.durationSec,
    required this.distanceM,
    required this.calories,
    required this.source,
    required this.createdAt,
    this.endedAt,
    this.avgSpeedCmS,
    this.maxSpeedCmS,
    this.avgHrBpm,
    this.minHrBpm,
    this.maxHrBpm,
    this.steps,
    this.stepRate,
    this.elevationCm,
    this.uphillCm,
    this.downhillCm,
  });

  final String id;
  final String userId;
  final String deviceId;
  final int sportType; // SDK byte — see BleService.sportTypeX constants.
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final int distanceM;
  final double calories;
  final int? avgSpeedCmS;
  final int? maxSpeedCmS;
  final int? avgHrBpm;
  final int? minHrBpm;
  final int? maxHrBpm;
  final int? steps;
  final int? stepRate;
  final int? elevationCm;
  final int? uphillCm;
  final int? downhillCm;
  final DataSource source;
  final DateTime createdAt;
}

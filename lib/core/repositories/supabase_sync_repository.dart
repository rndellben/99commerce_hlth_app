import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/models/baseline.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/device.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/services/supabase_connection_monitor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pushes domain models to Supabase via PostgREST upserts.
///
/// Manual map conversion (no codegen). Matches the pattern used by
/// Drift repositories (`_rowToDomain` / `_toCompanion`).
///
/// Every push method maps `local-user-v1` to the real Supabase auth UUID.
class SupabaseSyncRepository {
  SupabaseSyncRepository(this._client);

  final SupabaseClient _client;

  /// Push a daily_metrics row. Upserts on (user_id, local_date).
  Future<void> pushDailyMetrics(DailyMetrics m, String authUserId) async {
    await SupabaseConnectionMonitor.withRetry(() async {
      await _client.from('daily_metrics').upsert(
        _dailyMetricsToMap(m, authUserId),
        onConflict: 'user_id,local_date',
      );
    });
  }

  /// Push a baseline row. Upserts on (user_id, metric_key, window_days, computed_for_date).
  Future<void> pushBaseline(Baseline b, String authUserId) async {
    await SupabaseConnectionMonitor.withRetry(() async {
      await _client.from('baselines').upsert(
        _baselineToMap(b, authUserId),
        onConflict: 'user_id,metric_key,window_days,computed_for_date',
      );
    });
  }

  /// Push a device row. Upserts on id (PK).
  Future<void> pushDevice(Device d, String authUserId) async {
    await SupabaseConnectionMonitor.withRetry(() async {
      await _client.from('devices').upsert(
        _deviceToMap(d, authUserId),
        onConflict: 'id',
      );
    });
  }

  /// Push a user_profile row. Upserts on user_id (PK).
  Future<void> pushUserProfile(UserProfile p, String authUserId) async {
    await SupabaseConnectionMonitor.withRetry(() async {
      await _client.from('user_profiles').upsert(
        _userProfileToMap(p, authUserId),
        onConflict: 'user_id',
      );
    });
  }

  // ── Map builders ─────────────────────────────────────────────────────────

  Map<String, dynamic> _dailyMetricsToMap(DailyMetrics m, String uid) => {
        'id': m.id,
        'user_id': uid,
        'local_date': _dateStr(m.localDate),
        'tz_offset_min': m.tzOffsetMin,
        // Cardiac
        'resting_hr_bpm': m.restingHrBpm,
        'hrv_rmssd_ms': m.hrvRmssdMs,
        'hrv_sdnn_ms': m.hrvSdnnMs,
        'resting_resp_rate_bpm': m.restingRespRateBpm,
        // SpO2
        'spo2_overnight_avg': m.spo2OvernightAvg,
        'spo2_overnight_min': m.spo2OvernightMin,
        // BP
        'systolic_mmhg': m.systolicMmhg,
        'diastolic_mmhg': m.diastolicMmhg,
        // Sleep
        'sleep_total_min': m.sleepTotalMin,
        'sleep_deep_pct': m.sleepDeepPct,
        'sleep_rem_pct': m.sleepRemPct,
        'sleep_light_pct': m.sleepLightPct,
        'sleep_efficiency_pct': m.sleepEfficiencyPct,
        'bedtime_utc': m.bedtime?.toUtc().toIso8601String(),
        'wake_utc': m.wake?.toUtc().toIso8601String(),
        // Activity
        'steps': m.steps,
        'distance_m': m.distanceM,
        'calories_kcal': m.caloriesKcal,
        'active_minutes': m.activeMinutes,
        // Vascular
        'stiffness_index': m.stiffnessIndex,
        'augmentation_index': m.augmentationIndex,
        'stroke_volume_index': m.strokeVolumeIndex,
        'breathing_disruptions_hr': m.breathingDisruptionsHr,
        // Scores
        'recovery_score': m.recoveryScore,
        'wellness_score': m.wellnessScore,
        // Cycle
        'cycle_phase': m.cyclePhase,
        // Provenance
        'computed_at': m.computedAt.toUtc().toIso8601String(),
        'algorithm_version': m.algorithmVersion,
        'source': m.source.index,
      };

  Map<String, dynamic> _baselineToMap(Baseline b, String uid) => {
        'id': b.id,
        'user_id': uid,
        'metric_key': b.metricKey,
        'window_days': b.windowDays,
        'computed_for_date': _dateStr(b.computedForDate),
        'mean_value': b.meanValue,
        'stddev_value': b.stddevValue,
        'sample_count': b.sampleCount,
        'computed_at': b.computedAt.toUtc().toIso8601String(),
        'algorithm_version': b.algorithmVersion,
      };

  Map<String, dynamic> _deviceToMap(Device d, String uid) => {
        'id': d.id,
        'user_id': uid,
        'mac_address': d.macAddress,
        'ios_peripheral_uuid': d.iosPeripheralUuid,
        'display_name': d.displayName,
        'model': d.model,
        'hardware_version': d.hardwareVersion,
        'firmware_version': d.firmwareVersion,
        'user_id_on_band': d.userIdOnBand,
        'paired_at': d.pairedAt.toUtc().toIso8601String(),
        'last_connected_at': d.lastConnectedAt?.toUtc().toIso8601String(),
        'last_battery_percent': d.lastBatteryPercent,
        'last_charging': d.lastCharging,
        'is_active': d.isActive,
        'capabilities': d.capabilities,
      };

  Map<String, dynamic> _userProfileToMap(UserProfile p, String uid) => {
        'user_id': uid,
        'date_of_birth': p.dateOfBirth != null ? _dateStr(p.dateOfBirth!) : null,
        'sex_at_birth': p.sexAtBirth.index,
        'height_cm': p.heightCm,
        'weight_kg': p.weightKg,
        'uses_metric': p.usesMetric,
        'uses_24h_clock': p.uses24hClock,
        'resting_hr_baseline': p.restingHrBaseline,
        'cycle_tracking_enabled': p.cycleTrackingEnabled,
        'last_period_start_date':
            p.lastPeriodStartDate != null ? _dateStr(p.lastPeriodStartDate!) : null,
        'typical_cycle_length': p.typicalCycleLength,
        'updated_at': p.updatedAt.toUtc().toIso8601String(),
      };

  /// Format DateTime as YYYY-MM-DD date string.
  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

final supabaseSyncRepositoryProvider =
    Provider<SupabaseSyncRepository>((ref) {
  return SupabaseSyncRepository(ref.watch(supabaseClientProvider));
});

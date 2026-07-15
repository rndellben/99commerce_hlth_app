import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/core/providers/user_profile_provider.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:uuid/uuid.dart';

/// Application logic for the Blood Pressure feature — measurement,
/// persistence, and the calibration transaction. Extracted from
/// `blood_pressure_screen.dart` so the widgets only render state and
/// forward intents; everything that touches BLE or repositories lives
/// here where it can be tested without a widget tree.
class BpController {
  BpController(this._ref);

  final Ref _ref;

  /// Age from date of birth, clamped to the band SDK's sane range.
  /// Defaults to 30 when the profile has no DOB (matches the band's
  /// own fallback behavior for personal-info writes).
  static int ageFromDob(DateTime? dob) {
    if (dob == null) return 30;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age -= 1;
    }
    return age.clamp(13, 100);
  }

  /// Classic (220 − age) max-HR estimate, clamped to the band's accepted
  /// warn-threshold range.
  static int maxHrForAge(int age) => (220 - age).clamp(120, 200);

  /// One on-demand cuffless measurement (the only real BP path on H59 —
  /// there is no retrievable scheduled-BP history). Returns the parsed
  /// pair; a value ≤ 0 means the band did not converge.
  Future<({int sbp, int dbp})> measure() async {
    final r = await _ref.read(bleServiceProvider).startBpMeasurement();
    return (
      sbp: (r['sbp'] as int?) ?? 0,
      dbp: (r['dbp'] as int?) ?? 0,
    );
  }

  /// Persists a converged band measurement. Returns false when no active
  /// device row exists (nothing is stored, mirroring the long-standing
  /// behavior of the Measure Now flow).
  Future<bool> storeBandReading({required int sbp, required int dbp}) async {
    final device = await _ref
        .read(deviceRepositoryProvider)
        .getActiveForUser(ActiveSession.defaultUserId);
    if (device == null) return false;
    final now = DateTime.now();
    await _ref.read(bpRepositoryProvider).insert(BpReading(
          id: const Uuid().v4(),
          userId: ActiveSession.defaultUserId,
          deviceId: device.id,
          capturedAt: now.toUtc(),
          tzOffsetMin: now.timeZoneOffset.inMinutes,
          systolicMmhg: sbp,
          diastolicMmhg: dbp,
          derivation: BpDerivation.bandSensor,
          source: DataSource.bandManual,
        ));
    return true;
  }

  /// Persists a user-entered cuff reading from the Add Reading form.
  Future<void> storeManualReading({
    required int sbp,
    required int dbp,
    int? pulseBpm,
  }) async {
    final device = await _ref
        .read(deviceRepositoryProvider)
        .getActiveForUser(ActiveSession.defaultUserId);
    final now = DateTime.now();
    await _ref.read(bpRepositoryProvider).insert(BpReading(
          id: const Uuid().v4(),
          userId: ActiveSession.defaultUserId,
          deviceId: device?.id ?? '',
          capturedAt: now.toUtc(),
          tzOffsetMin: now.timeZoneOffset.inMinutes,
          systolicMmhg: sbp,
          diastolicMmhg: dbp,
          pulseBpm: pulseBpm,
          derivation: BpDerivation.cuff,
          source: DataSource.userEntered,
        ));
  }

  /// The calibration transaction: average the three cuff readings, persist
  /// a new active `BpCalibration` (with the HR/age anchor), then push the
  /// personal-info baseline to the band. Returns true when the band write
  /// was acknowledged (and recorded as such).
  Future<bool> saveCalibration({
    required List<({int sbp, int dbp})> readings,
    String? notes,
  }) async {
    final avgSbp =
        (readings.fold(0, (a, r) => a + r.sbp) / readings.length).round();
    final avgDbp =
        (readings.fold(0, (a, r) => a + r.dbp) / readings.length).round();

    final profile = _ref.read(userProfileProvider).valueOrNull;
    final age = ageFromDob(profile?.dateOfBirth);
    final hrNow = _ref.read(latestHrSampleProvider).valueOrNull?.bpm;
    final calibrationId = const Uuid().v4();
    final now = DateTime.now();
    final calibration = BpCalibration(
      id: calibrationId,
      userId: ActiveSession.defaultUserId,
      capturedAt: now.toUtc(),
      cuffSystolic: avgSbp,
      cuffDiastolic: avgDbp,
      hrAtCalibration: hrNow,
      ageAtCalibration: age,
      notes: notes,
      isActive: true,
      createdAt: now.toUtc(),
    );
    await _ref
        .read(bpCalibrationRepositoryProvider)
        .upsertNewActive(calibration);

    final ble = _ref.read(bleServiceProvider);
    final isMale = profile?.sexAtBirth == SexAtBirth.male;
    final ok = await ble.setPersonalInfo(
      isMale: isMale,
      age: age,
      heightCm: profile?.heightCm?.round() ?? 170,
      weightKg: profile?.weightKg?.round() ?? 70,
      baselineSbp: avgSbp,
      baselineDbp: avgDbp,
      hrWarnHigh: maxHrForAge(age),
    );
    if (ok) {
      await _ref
          .read(bpCalibrationRepositoryProvider)
          .markBandWriteSucceeded(calibrationId);
    }
    return ok;
  }
}

final bpControllerProvider = Provider<BpController>((ref) {
  return BpController(ref);
});

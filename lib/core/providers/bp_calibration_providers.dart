import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/processing/bp_formula.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';

/// Streams the currently-active calibration for the default user, so any
/// widget that wants to render "Calibrated 132/85 · 2 days ago" or apply
/// `BpFormula(cuff: ...)` to a display value gets live updates the moment
/// the user re-calibrates.
final activeBpCalibrationProvider =
    StreamProvider<BpCalibration?>((ref) {
  final repo = ref.watch(bpCalibrationRepositoryProvider);
  return repo.watchActiveForUser(ActiveSession.defaultUserId);
});

/// History list of calibrations (active first, then inactive descending).
/// Used by the calibration-history sheet if/when we add one.
final bpCalibrationHistoryProvider =
    StreamProvider<List<BpCalibration>>((ref) {
  final repo = ref.watch(bpCalibrationRepositoryProvider);
  return repo.watchHistoryForUser(ActiveSession.defaultUserId);
});

/// A single BP reading paired with its calibrated values, so the UI can
/// show both ("Calibrated: 130/82 · Raw: 118/76") when that's useful.
class BpReadingWithCalibration {
  const BpReadingWithCalibration({
    required this.reading,
    required this.calibrated,
  });

  final BpReading reading;
  final CalibratedBp calibrated;

  /// Resolved SBP to display — calibrated when an anchor was applied,
  /// else the raw band value.
  int get displaySbp => calibrated.sbp;
  int get displayDbp => calibrated.dbp;
  bool get isCalibrated => calibrated.appCalibrated;
}

/// Applies the active cuff [cal] to one raw band [reading].
///
/// Shared by the BP headline ([calibratedLatestBpProvider]) and the BP trend
/// chart so the two can never disagree about the same reading.
///
/// `applyBpCalibration` chooses its branch on the READING's HR, but uses
/// `anchor.hrAtCalibration` as that branch's baseline
/// (`bp_formula.dart:143-150`). A calibration row can be saved with no HR at
/// all — `hrAtCalibration` is nullable end-to-end and the save path reads a
/// provider that is null while `hr_samples` is empty
/// (`bp_controller.dart:115`) — and there is no baseline to couple to in that
/// case. Passing the reading's HR anyway makes the coupled branch compute
/// `cuffSbp + (hr − 0) × 0.45`, which overstates the model's own intended
/// systolic by a constant +9…+49 mmHg depending on age bracket. So withhold
/// the reading's HR when the anchor has none, which selects the constant
/// offset the no-anchor-HR case is meant to use: `raw + (cuffSbp − 120)`.
///
/// Neither branch is a pressure measurement — both are arithmetic over HR and
/// age with no sensor behind them. This only keeps the display consistent
/// with the model the app already ships.
CalibratedBp calibrateBpReading({
  required BpReading reading,
  required BpCalibration? cal,
}) {
  if (cal == null) {
    return applyBpCalibration(
      rawSbp: reading.systolicMmhg,
      rawDbp: reading.diastolicMmhg,
    );
  }
  final anchorHr = cal.hrAtCalibration;
  return applyBpCalibration(
    rawSbp: reading.systolicMmhg,
    rawDbp: reading.diastolicMmhg,
    // Withheld when the anchor carries no HR — see above.
    hr: anchorHr == null ? null : reading.pulseBpm,
    anchor: BpCalibrationAnchor(
      systolic: cal.cuffSystolic,
      diastolic: cal.cuffDiastolic,
      // Genuinely inert when anchorHr is null: `hr` is null above, so the
      // constant-offset branch runs and never reads this field.
      hrAtCalibration: anchorHr ?? 0,
    ),
  );
}

/// Latest stored BP reading with the active calibration applied. Use
/// this in headlines and home cards instead of the raw `latestBpReadingProvider`
/// so the user sees their personalized values.
final calibratedLatestBpProvider =
    StreamProvider<BpReadingWithCalibration?>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  final calAsync = ref.watch(activeBpCalibrationProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId).map((reading) {
    if (reading == null) return null;
    return BpReadingWithCalibration(
      reading: reading,
      calibrated: calibrateBpReading(
        reading: reading,
        cal: calAsync.valueOrNull,
      ),
    );
  });
});

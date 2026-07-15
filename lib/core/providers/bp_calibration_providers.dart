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

BpCalibrationAnchor? _anchorFor(BpCalibration? cal) {
  if (cal == null || cal.hrAtCalibration == null) {
    if (cal == null) return null;
    // Anchor without HR — applyBpCalibration's constant-offset branch
    // handles this case via the rawHr == null fallback. Returning a
    // sentinel anchor with HR = 0 would mis-trigger the HR-coupled path
    // and produce wildly wrong values; instead we return null here so
    // the apply helper falls through to its no-anchor branch and we
    // separately apply the offset.
    //
    // …except `applyBpCalibration` does that fallback only when the
    // ANCHOR is present and HR is missing. So we DO want to pass an
    // anchor; just keep `hrAtCalibration` at a safe default that's
    // ignored by the offset branch.
    return BpCalibrationAnchor(
      systolic: cal.cuffSystolic,
      diastolic: cal.cuffDiastolic,
      hrAtCalibration: 0, // ignored by the offset-fallback branch
    );
  }
  return BpCalibrationAnchor(
    systolic: cal.cuffSystolic,
    diastolic: cal.cuffDiastolic,
    hrAtCalibration: cal.hrAtCalibration!,
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
    final cal = calAsync.valueOrNull;
    final anchor = _anchorFor(cal);
    final calibrated = applyBpCalibration(
      rawSbp: reading.systolicMmhg,
      rawDbp: reading.diastolicMmhg,
      hr: reading.pulseBpm,
      anchor: anchor,
    );
    return BpReadingWithCalibration(
      reading: reading,
      calibrated: calibrated,
    );
  });
});

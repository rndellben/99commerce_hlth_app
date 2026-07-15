import 'package:hlth_app/core/services/retention_sweep_service.dart';

/// Per-step result. `error` is non-null on failure; counts are best-effort.
///
/// `rawMap` / `rawList` carry the underlying BLE response so the debug
/// screen can dump the band's payload verbatim without making a second
/// (slower, expensive) BLE round-trip. Periodic scheduler ignores them.
class SyncStepResult {
  const SyncStepResult({
    required this.metric,
    required this.count,
    this.error,
    this.note,
    this.rawMap,
    this.rawList,
    this.extra,
  });

  final String metric;
  final int count;
  final String? error;
  final String? note;
  final Map<String, dynamic>? rawMap;
  final List<dynamic>? rawList;
  // Per-metric ancillary values (e.g. HR's resolved intervalMin, sleep's
  // session id) for callers that need more than count + raw payload.
  final Map<String, dynamic>? extra;

  bool get ok => error == null;
}

/// Aggregate of a `syncAll` run. Order matches execution order.
///
/// `retention` is populated by `PeriodicSyncCoordinator` when the daily
/// gate elapsed and a sweep ran; null otherwise. `retentionSkipReason`
/// is a short string ("last ran 4h ago") for visibility when the gate
/// blocked the sweep — only set when retention is null AND the gate is
/// the reason (not the case when the sweep ran successfully).
class SyncRunResult {
  const SyncRunResult({
    required this.steps,
    required this.aggregated,
    this.retention,
    this.retentionSkipReason,
  });

  final List<SyncStepResult> steps;
  final bool aggregated;
  final RetentionSweepResult? retention;
  final String? retentionSkipReason;

  int get totalSamples => steps.fold(0, (a, s) => a + s.count);
  Iterable<SyncStepResult> get failed => steps.where((s) => !s.ok);
  bool get allOk =>
      failed.isEmpty &&
      aggregated &&
      (retention == null || retention!.allOk);
}

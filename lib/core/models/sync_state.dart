import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';

/// hlth-db-schema.md §8.1 — per-device per-metric sync watermark.
@freezed
class SyncState with _$SyncState {
  const factory SyncState({
    required String id,
    required String deviceId,
    required String metricKey,
    DateTime? lastSuccessfulSync,
    DateTime? lastAttemptedSync,
    String? lastSyncError,
    int? lastSyncedDayIndex,
    @Default(0) int bytesSyncedLifetime,
  }) = _SyncState;
}

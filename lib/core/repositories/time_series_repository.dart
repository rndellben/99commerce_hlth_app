/// hlth-repository-api.md §4.3 — generic time-series CRUD surface.
///
/// Every per-metric sample table (HR, HRV, SpO2, BP, etc.) shares this
/// surface: insert, range query, latest, watch, count, soft delete.
/// Concrete repos extend this with metric-specific helpers.
abstract class TimeSeriesRepository<T> {
  Future<void> insert(T sample);
  Future<void> insertMany(List<T> samples);

  Future<T?> getLatest({
    required String userId,
    String? deviceId,
  });

  Future<List<T>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  });

  Stream<List<T>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  Stream<T?> watchLatest({required String userId});

  Future<int> countInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  /// Hard delete is only available via retention sweeps. This soft-deletes
  /// (sets `deleted_at_utc`) for any row whose `captured_at_utc` is older
  /// than `cutoff`. Returns the number of rows soft-deleted.
  Future<int> softDeleteBefore(DateTime cutoff);
}

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

/// One snapshot logged on each periodic-sync tick (and on connect / manual
/// triggers). Drives the BLE Debug "Battery Drain Test" panel. Records the
/// band's battery only — phone battery is intentionally not tracked since
/// Ryan's 2026-06-17 ask was specifically about the band.
class BatteryTelemetryRow {
  const BatteryTelemetryRow({
    required this.id,
    required this.capturedAtUtc,
    required this.bandBatteryPercent,
    required this.bandCharging,
    required this.syncIntervalMin,
    required this.eventType,
  });

  final String id;
  final DateTime capturedAtUtc;
  final int? bandBatteryPercent;
  final bool? bandCharging;
  final int syncIntervalMin;
  final String eventType; // 'tick' | 'connect' | 'manual'
}

/// Summary computed across all telemetry rows since the user last tapped
/// "Start new test" (i.e. since `_resetMarkerUtc`).
class BatteryDrainSummary {
  const BatteryDrainSummary({
    required this.firstSampleAt,
    required this.lastSampleAt,
    required this.firstBandPercent,
    required this.lastBandPercent,
    required this.sampleCount,
    required this.activeIntervalMin,
  });

  final DateTime? firstSampleAt;
  final DateTime? lastSampleAt;
  final int? firstBandPercent;
  final int? lastBandPercent;
  final int sampleCount;
  final int? activeIntervalMin;

  Duration get elapsed {
    if (firstSampleAt == null || lastSampleAt == null) return Duration.zero;
    return lastSampleAt!.difference(firstSampleAt!);
  }

  /// Drain in %/hour. Negative means the battery went UP (charging during
  /// the window) — surface as zero so the projection isn't nonsensical.
  double? get bandDrainPctPerHour {
    if (firstBandPercent == null || lastBandPercent == null) return null;
    final hours = elapsed.inSeconds / 3600;
    if (hours < 0.01) return null; // <36s elapsed — not enough signal
    final delta = firstBandPercent! - lastBandPercent!;
    return delta / hours;
  }

  /// Projected drop over a full 24h at the current rate. Capped at 100%.
  double? get bandProjected24h {
    final rate = bandDrainPctPerHour;
    if (rate == null) return null;
    return (rate * 24).clamp(0, 100).toDouble();
  }
}

abstract class BatteryTelemetryRepository {
  Future<void> insert({
    required int? bandBatteryPercent,
    required bool? bandCharging,
    required int syncIntervalMin,
    required String eventType,
  });

  /// All rows since [sinceUtc] in ascending capturedAtUtc order.
  Future<List<BatteryTelemetryRow>> getSince(DateTime sinceUtc);

  Stream<BatteryDrainSummary> watchSummary(DateTime sinceUtc);

  /// CSV dump of [since…now] for the "Export CSV" debug button.
  Future<String> exportCsv(DateTime sinceUtc);
}

class BatteryTelemetryRepositoryImpl implements BatteryTelemetryRepository {
  BatteryTelemetryRepositoryImpl(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  @override
  Future<void> insert({
    required int? bandBatteryPercent,
    required bool? bandCharging,
    required int syncIntervalMin,
    required String eventType,
  }) async {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _db.into(_db.batteryTelemetry).insert(
          BatteryTelemetryCompanion.insert(
            id: _uuid.v4(),
            capturedAtUtc: nowSec,
            bandBatteryPercent: Value(bandBatteryPercent),
            bandCharging: Value(bandCharging),
            syncIntervalMin: syncIntervalMin,
            eventType: eventType,
          ),
        );
  }

  @override
  Future<List<BatteryTelemetryRow>> getSince(DateTime sinceUtc) async {
    final sinceSec = sinceUtc.toUtc().millisecondsSinceEpoch ~/ 1000;
    final rows = await (_db.select(_db.batteryTelemetry)
          ..where((t) => t.capturedAtUtc.isBiggerOrEqualValue(sinceSec))
          ..orderBy([(t) => OrderingTerm(expression: t.capturedAtUtc)]))
        .get();
    return rows.map(_toRow).toList();
  }

  @override
  Stream<BatteryDrainSummary> watchSummary(DateTime sinceUtc) {
    final sinceSec = sinceUtc.toUtc().millisecondsSinceEpoch ~/ 1000;
    final query = (_db.select(_db.batteryTelemetry)
      ..where((t) => t.capturedAtUtc.isBiggerOrEqualValue(sinceSec))
      ..orderBy([(t) => OrderingTerm(expression: t.capturedAtUtc)]));
    return query.watch().map(_summarize);
  }

  @override
  Future<String> exportCsv(DateTime sinceUtc) async {
    final rows = await getSince(sinceUtc);
    final buf = StringBuffer()
      ..writeln(
        'captured_at_utc,band_battery_percent,band_charging,sync_interval_min,event_type',
      );
    for (final r in rows) {
      buf.writeln([
        r.capturedAtUtc.toIso8601String(),
        r.bandBatteryPercent ?? '',
        r.bandCharging ?? '',
        r.syncIntervalMin,
        r.eventType,
      ].join(','));
    }
    return buf.toString();
  }

  BatteryTelemetryRow _toRow(BatteryTelemetryData d) => BatteryTelemetryRow(
        id: d.id,
        capturedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          d.capturedAtUtc * 1000,
          isUtc: true,
        ),
        bandBatteryPercent: d.bandBatteryPercent,
        bandCharging: d.bandCharging,
        syncIntervalMin: d.syncIntervalMin,
        eventType: d.eventType,
      );

  BatteryDrainSummary _summarize(List<BatteryTelemetryData> rows) {
    if (rows.isEmpty) {
      return const BatteryDrainSummary(
        firstSampleAt: null,
        lastSampleAt: null,
        firstBandPercent: null,
        lastBandPercent: null,
        sampleCount: 0,
        activeIntervalMin: null,
      );
    }
    // First/last NON-NULL band values so a single missed read doesn't
    // collapse the summary.
    int? firstBand;
    int? lastBand;
    for (final r in rows) {
      if (r.bandBatteryPercent != null) {
        firstBand ??= r.bandBatteryPercent;
        lastBand = r.bandBatteryPercent;
      }
    }
    return BatteryDrainSummary(
      firstSampleAt: DateTime.fromMillisecondsSinceEpoch(
        rows.first.capturedAtUtc * 1000,
        isUtc: true,
      ),
      lastSampleAt: DateTime.fromMillisecondsSinceEpoch(
        rows.last.capturedAtUtc * 1000,
        isUtc: true,
      ),
      firstBandPercent: firstBand,
      lastBandPercent: lastBand,
      sampleCount: rows.length,
      activeIntervalMin: rows.last.syncIntervalMin,
    );
  }
}

final batteryTelemetryRepositoryProvider =
    Provider<BatteryTelemetryRepository>((ref) {
  return BatteryTelemetryRepositoryImpl(ref.watch(appDatabaseProvider));
});

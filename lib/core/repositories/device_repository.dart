import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/device.dart';

/// hlth-repository-api.md §4.2
abstract class DeviceRepository {
  Future<Device> create({
    required String id,
    required String userId,
    required String displayName,
    String? macAddress,
    String? iosPeripheralUuid,
    String? model,
  });

  Future<Device?> getById(String deviceId);
  Future<Device?> getByMacAddress(String mac);
  Future<List<Device>> getAllForUser(String userId, {bool includeInactive = false});
  Future<Device?> getActiveForUser(String userId);
  Stream<Device?> watchActive(String userId);

  Future<void> updateConnectionState({
    required String deviceId,
    required DateTime lastConnectedAt,
    int? batteryPercent,
    bool? charging,
  });

  Future<void> updateFirmwareInfo({
    required String deviceId,
    String? firmwareVersion,
    String? hardwareVersion,
  });

  Future<void> updateCapabilities({
    required String deviceId,
    required Map<String, dynamic> capabilities,
  });

  Future<bool> hasCapability(String deviceId, String capabilityKey);
  Future<void> deactivate(String deviceId);

  /// Re-mark a previously-deactivated device row as active. Used by the
  /// re-pair flow after Forget: the row already exists (matched by MAC)
  /// so we restore its isActive flag instead of creating a duplicate.
  Future<void> reactivate(String deviceId);

  /// Set a friendly name for the device (local alias only — the band's
  /// advertised BLE name cannot be changed via firmware).
  Future<void> rename({required String deviceId, required String displayName});
}

class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl(this._db);
  final db.AppDatabase _db;

  @override
  Future<Device> create({
    required String id,
    required String userId,
    required String displayName,
    String? macAddress,
    String? iosPeripheralUuid,
    String? model,
  }) async {
    final now = DateTime.now().toUtc();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    await _db.into(_db.devices).insert(
          db.DevicesCompanion.insert(
            id: id,
            userId: userId,
            macAddress: Value(macAddress),
            iosPeripheralUuid: Value(iosPeripheralUuid),
            displayName: displayName,
            model: Value(model),
            pairedAtUtc: nowSec,
          ),
        );
    return Device(
      id: id,
      userId: userId,
      macAddress: macAddress,
      iosPeripheralUuid: iosPeripheralUuid,
      displayName: displayName,
      model: model,
      pairedAt: now,
    );
  }

  @override
  Future<Device?> getById(String deviceId) async {
    final row = await (_db.select(_db.devices)
          ..where((t) => t.id.equals(deviceId)))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<Device?> getByMacAddress(String mac) async {
    final row = await (_db.select(_db.devices)
          ..where((t) => t.macAddress.equals(mac)))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<Device>> getAllForUser(String userId,
      {bool includeInactive = false}) async {
    final query = _db.select(_db.devices)
      ..where((t) => t.userId.equals(userId));
    if (!includeInactive) {
      query.where((t) => t.isActive.equals(true));
    }
    final rows = await query.get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<Device?> getActiveForUser(String userId) async {
    final row = await (_db.select(_db.devices)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.pairedAtUtc)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Stream<Device?> watchActive(String userId) {
    return (_db.select(_db.devices)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.pairedAtUtc)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToDomain(row));
  }

  @override
  Future<void> updateConnectionState({
    required String deviceId,
    required DateTime lastConnectedAt,
    int? batteryPercent,
    bool? charging,
  }) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId))).write(
      db.DevicesCompanion(
        lastConnectedAtUtc:
            Value(lastConnectedAt.toUtc().millisecondsSinceEpoch ~/ 1000),
        lastBatteryPercent: Value(batteryPercent),
        lastCharging: Value(charging),
      ),
    );
  }

  @override
  Future<void> updateFirmwareInfo({
    required String deviceId,
    String? firmwareVersion,
    String? hardwareVersion,
  }) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId))).write(
      db.DevicesCompanion(
        firmwareVersion: Value(firmwareVersion),
        hardwareVersion: Value(hardwareVersion),
      ),
    );
  }

  @override
  Future<void> updateCapabilities({
    required String deviceId,
    required Map<String, dynamic> capabilities,
  }) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId))).write(
      db.DevicesCompanion(capabilities: Value(jsonEncode(capabilities))),
    );
  }

  @override
  Future<bool> hasCapability(String deviceId, String capabilityKey) async {
    final d = await getById(deviceId);
    if (d == null) return false;
    final v = d.capabilities[capabilityKey];
    return v == true;
  }

  @override
  Future<void> deactivate(String deviceId) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId)))
        .write(const db.DevicesCompanion(isActive: Value(false)));
  }

  @override
  Future<void> reactivate(String deviceId) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId)))
        .write(const db.DevicesCompanion(isActive: Value(true)));
  }

  @override
  Future<void> rename({
    required String deviceId,
    required String displayName,
  }) async {
    await (_db.update(_db.devices)..where((t) => t.id.equals(deviceId))).write(
      db.DevicesCompanion(displayName: Value(displayName)),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  Device _rowToDomain(db.Device r) {
    Map<String, dynamic> caps;
    try {
      caps = Map<String, dynamic>.from(jsonDecode(r.capabilities) as Map);
    } catch (_) {
      caps = const {};
    }
    return Device(
      id: r.id,
      userId: r.userId,
      macAddress: r.macAddress,
      iosPeripheralUuid: r.iosPeripheralUuid,
      displayName: r.displayName,
      model: r.model,
      hardwareVersion: r.hardwareVersion,
      firmwareVersion: r.firmwareVersion,
      userIdOnBand: r.userIdOnBand,
      pairedAt: _utcSecToDt(r.pairedAtUtc),
      lastConnectedAt:
          r.lastConnectedAtUtc == null ? null : _utcSecToDt(r.lastConnectedAtUtc!),
      lastBatteryPercent: r.lastBatteryPercent,
      lastCharging: r.lastCharging,
      isActive: r.isActive,
      capabilities: caps,
      deletedAt: r.deletedAtUtc == null ? null : _utcSecToDt(r.deletedAtUtc!),
    );
  }

  DateTime _utcSecToDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepositoryImpl(ref.watch(db.appDatabaseProvider));
});

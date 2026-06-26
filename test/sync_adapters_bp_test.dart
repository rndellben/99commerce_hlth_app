import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/sync_adapters.dart';
import 'package:hlth_app/core/database/enums.dart';

/// Unit tests for the scheduled-BP day adapter: it maps the SDK's
/// `{readings:[{time,sbp,dbp}]}` shape to canonical BpReadings, drops the
/// band's non-convergence sentinels, and assigns deterministic ids so a
/// full-day re-pull on every sync tick overwrites instead of duplicating.
void main() {
  const tEpochSec = 1780000800; // 2026-06-04 22:00:00 UTC

  Map<String, dynamic> native(List<Map<String, dynamic>> readings) =>
      {'readings': readings};

  test('maps sbp/dbp + UTC time, tags provenance', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out, hasLength(1));
    final r = out.single;
    expect(r.systolicMmhg, 122);
    expect(r.diastolicMmhg, 78);
    expect(r.capturedAt,
        DateTime.fromMillisecondsSinceEpoch(tEpochSec * 1000, isUtc: true));
    expect(r.source, DataSource.bandScheduled);
    expect(r.derivation, BpDerivation.bandSensor);
  });

  test('drops non-convergence sentinels (sbp<=0 or dbp<=0) and time<=0', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 0, 'dbp': 80}, // band didn't converge
        {'time': tEpochSec + 3600, 'sbp': 120, 'dbp': 0},
        {'time': 0, 'sbp': 118, 'dbp': 76}, // no timestamp
        {'time': tEpochSec + 7200, 'sbp': 119, 'dbp': 77}, // valid
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out, hasLength(1));
    expect(out.single.systolicMmhg, 119);
  });

  test('id is deterministic per (deviceId, second) — re-pull overwrites', () {
    final first = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd',
    ).single;
    final second = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 125, 'dbp': 80}, // same instant, new value
      ]),
      userId: 'u',
      deviceId: 'd',
    ).single;
    // Same id → insertOnConflictUpdate overwrites rather than duplicating.
    expect(first.id, second.id);
    // Different device → different id.
    final other = bpFromNative(
      native([
        {'time': tEpochSec, 'sbp': 122, 'dbp': 78},
      ]),
      userId: 'u',
      deviceId: 'd2',
    ).single;
    expect(other.id, isNot(first.id));
  });

  test('accepts millisecond timestamps (magnitude auto-detect)', () {
    final out = bpFromNative(
      native([
        {'time': tEpochSec * 1000, 'sbp': 120, 'dbp': 80},
      ]),
      userId: 'u',
      deviceId: 'd',
    );
    expect(out.single.capturedAt,
        DateTime.fromMillisecondsSinceEpoch(tEpochSec * 1000, isUtc: true));
  });

  test('empty / missing readings → empty list', () {
    expect(bpFromNative(const {}, userId: 'u', deviceId: 'd'), isEmpty);
    expect(bpFromNative(native(const []), userId: 'u', deviceId: 'd'), isEmpty);
  });
}

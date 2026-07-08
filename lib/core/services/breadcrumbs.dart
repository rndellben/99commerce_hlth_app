import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Tiny persistent trail of background events — ticks, reconnect attempts,
/// capture fires/skips, alert decisions.
///
/// Why it exists: the 2026-07-07 overnight failure was undiagnosable after
/// the fact — the BLE Debug log is in-memory (dies with the process), MIUI's
/// logcat buffer rotates within hours, and release builds don't emit Dart
/// prints. This file survives process death and reinstalls-in-place, so
/// "what happened overnight?" has an answer the next morning.
///
/// Plain text, one line per event, newest last, self-trimming on boot.
/// Writes are synchronous appends — crumbs fire at tick cadence (minutes
/// apart), so the cost is negligible and a sync write can't be lost to a
/// kill the way a buffered one can.
class Breadcrumbs {
  Breadcrumbs._();

  static File? _file;
  static const _maxLines = 800;

  /// Open (and trim) the crumb file. Call once per engine boot — both
  /// `main()` and `backgroundMain()`. Never throws; on failure logging
  /// becomes a no-op.
  static Future<void> init(String engineLabel) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/breadcrumbs.log');
      if (await f.exists()) {
        final lines = await f.readAsLines();
        if (lines.length > _maxLines) {
          await f.writeAsString(
            '${lines.sublist(lines.length - _maxLines).join('\n')}\n',
          );
        }
      } else {
        await f.create(recursive: true);
      }
      _file = f;
      log('boot [$engineLabel]');
    } catch (e) {
      debugPrint('[crumbs] init failed: $e');
    }
  }

  /// Append one timestamped line. No-op before [init] or after any failure.
  static void log(String message) {
    final f = _file;
    if (f == null) return;
    try {
      final ts = DateTime.now().toIso8601String().substring(0, 19);
      f.writeAsStringSync('$ts $message\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Last [lines] crumbs, oldest first — for the debug screen.
  static Future<List<String>> tail({int lines = 200}) async {
    try {
      final f = _file;
      if (f == null || !await f.exists()) return const [];
      final all = await f.readAsLines();
      return all.length <= lines ? all : all.sublist(all.length - lines);
    } catch (_) {
      return const [];
    }
  }
}

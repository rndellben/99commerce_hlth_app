// Temporary scaffold — to be replaced by the freezed `RawPpgSample` model
// in step 5 (per hlth-repository-api.md §4.4). For now, just holds enough
// shape so existing BLE streams compile while we migrate.
//
// The typed PPG streams (_ppgData / _accelData in BleService) are not
// consumed by any UI yet — debug screen uses rawPpgEvent. So this is
// effectively dead code, kept as a placeholder.

class PpgSample {
  final int timestampMs;
  final int? green;
  final int? red;
  final int? infrared;

  const PpgSample({
    required this.timestampMs,
    this.green,
    this.red,
    this.infrared,
  });

  factory PpgSample.fromMap(Map<String, dynamic> m) => PpgSample(
        timestampMs: (m['timestamp_ms'] as num).toInt(),
        green: (m['green'] as num?)?.toInt(),
        red: (m['red'] as num?)?.toInt(),
        infrared: (m['infrared'] as num?)?.toInt(),
      );
}

class AccelerometerSample {
  final int timestampMs;
  final int x;
  final int y;
  final int z;

  const AccelerometerSample({
    required this.timestampMs,
    required this.x,
    required this.y,
    required this.z,
  });
}

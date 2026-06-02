// Temporary scaffold — return shape for HrvCalculator. Step 5 will fold
// this into the freezed `HrvSample` model from hlth-repository-api.md
// §3 and rewire the signal-processing pipeline accordingly.

class HrvMetrics {
  final double meanRr;
  final double sdnn;
  final double rmssd;
  final double pnn50;
  final double meanHr;

  const HrvMetrics({
    required this.meanRr,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.meanHr,
  });

  /// Primer §6 sanity ranges — reject outliers.
  bool get isValid =>
      rmssd >= 5 &&
      rmssd <= 300 &&
      sdnn >= 10 &&
      sdnn <= 400 &&
      meanHr >= 30 &&
      meanHr <= 220;
}

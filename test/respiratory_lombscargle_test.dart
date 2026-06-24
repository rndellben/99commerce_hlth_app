import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/respiratory_lombscargle.dart';

void main() {
  // Deterministic LCG so the synthetic "noise" case is reproducible.
  double Function() lcg(int seed) {
    var s = seed & 0x7fffffff;
    return () {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff; // 0..1
    };
  }

  /// R-R series with a known RSA respiratory modulation. When [lossFrac] > 0,
  /// some beats are "dropped": the interval is doubled (a stitched gap) and the
  /// mask marks it invalid.
  ({List<double> rr, List<bool> mask}) synthRr(
    double respBpm, {
    double hrBpm = 72,
    double durS = 120,
    double rsaMs = 35,
    double lossFrac = 0.0,
    int seed = 7,
  }) {
    final meanRr = 60000.0 / hrBpm;
    final fResp = respBpm / 60.0;
    final rand = lcg(seed);
    final rr = <double>[];
    final mask = <bool>[];
    double t = 0;
    while (t < durS * 1000.0) {
      final phase = 2 * math.pi * fResp * (t / 1000.0);
      final jitter = (rand() - 0.5) * 8.0; // ±4 ms deterministic wobble
      final v = meanRr + rsaMs * math.sin(phase) + jitter;
      if (lossFrac > 0 && rand() < lossFrac) {
        rr.add(v * 2); // stitched gap interval
        mask.add(false);
        t += v * 2;
      } else {
        rr.add(v);
        mask.add(true);
        t += v;
      }
    }
    return (rr: rr, mask: mask);
  }

  test('clean signal recovers 14 br/min', () {
    final s = synthRr(14.0, hrBpm: 72, durS: 120);
    final res = estimateRespiratoryRate(s.rr, rrValidMask: s.mask);

    expect(res.ok, isTrue, reason: res.reason);
    expect(res.respBpm, closeTo(14.0, 1.5), reason: 'got ${res.respBpm}');
  });

  test('holds at 14 br/min through 12% packet loss (real-beats-only)', () {
    final s = synthRr(14.0, hrBpm: 91, durS: 120, lossFrac: 0.12);
    final res = estimateRespiratoryRate(s.rr, rrValidMask: s.mask);

    expect(res.ok, isTrue, reason: res.reason);
    expect(res.respBpm, closeTo(14.0, 1.5), reason: 'got ${res.respBpm}');
  });

  test('recovers a faster rate (22 br/min)', () {
    final s = synthRr(22.0, hrBpm: 80, durS: 120);
    final res = estimateRespiratoryRate(s.rr, rrValidMask: s.mask);

    expect(res.ok, isTrue, reason: res.reason);
    expect(res.respBpm, closeTo(22.0, 1.5), reason: 'got ${res.respBpm}');
  });

  test('refuses on pure noise instead of fabricating a number', () {
    final rand = lcg(11);
    final meanRr = 60000.0 / 72;
    final rr = [for (int i = 0; i < 160; i++) meanRr + (rand() - 0.5) * 12.0];
    final res = estimateRespiratoryRate(rr);

    expect(res.ok, isFalse);
    expect(res.respBpm, isNull);
  });

  test('refuses when too few beats', () {
    final rr = [for (int i = 0; i < 10; i++) 833.0];
    final res = estimateRespiratoryRate(rr);

    expect(res.ok, isFalse);
    expect(res.reason, contains('too few'));
  });
}

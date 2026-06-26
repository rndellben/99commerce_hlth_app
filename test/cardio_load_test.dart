import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart';

/// Behavioural checks on the vendored Vascular Load (Cardio Load) engine.
/// The Python validation builds its baseline with a seeded RNG that can't be
/// reproduced in Dart, so rather than pin exact figures these assert the
/// engine's documented invariants on deterministic inputs:
///   * cold start locks until 4 valid nights are banked,
///   * no valid sleep last night refuses,
///   * insufficient prior valid history refuses,
///   * a night identical to the baseline scores ~50 ("50 = baseline"),
///   * each input moves the score in its documented direction
///     (higher trough HR / lower HRV / higher stress -> more load -> higher score).
void main() {
  // One calm, moderate baseline night. All baseline nights are identical so a
  // tonight equal to them has ~zero load and should score ~50.
  NightlyRecord baselineNight(
    String date, {
    double hrP5 = 55,
    double rmssdMedian = 45,
    double stressMean = 30,
    bool valid = true,
  }) =>
      NightlyRecord(
        date: date,
        hrP5: hrP5,
        rmssdMedian: rmssdMedian,
        stressMean: stressMean,
        coverage: 0.9,
        valid: valid,
      );

  /// A history of [n] identical valid baseline nights, oldest-first.
  List<NightlyRecord> matureBaseline([int n = 6]) =>
      [for (var i = 0; i < n; i++) baselineNight('base-$i')];

  test('cold start: <4 banked valid nights is calibrating', () {
    final r = computeVascularLoad(
      history: [baselineNight('b0'), baselineNight('b1'), baselineNight('b2')],
      tonight: baselineNight('today'),
      bankedValidCount: 3,
    );
    expect(r.status, VlStatus.calibrating);
    // Message tells the user how many more sleeps are needed (4 - 3 = 1).
    expect(r.message, contains('1 more sleep'));
  });

  test('no valid sleep last night refuses, regardless of history', () {
    final r = computeVascularLoad(
      history: matureBaseline(),
      tonight: baselineNight('today', valid: false),
      bankedValidCount: 6,
    );
    expect(r.status, VlStatus.noData);
  });

  test('insufficient prior valid history refuses', () {
    // bankedValidCount clears the cold-start gate, but the history window
    // holds fewer than 3 valid records.
    final history = [
      baselineNight('h0'),
      baselineNight('h1', valid: false),
      baselineNight('h2', valid: false),
    ];
    final r = computeVascularLoad(
      history: history,
      tonight: baselineNight('today'),
      bankedValidCount: 6,
    );
    expect(r.status, VlStatus.noData);
  });

  test('a night identical to the baseline scores ~50', () {
    final history = matureBaseline();
    final r = computeVascularLoad(
      history: history,
      tonight: baselineNight('today'),
      bankedValidCount: history.length,
    );
    expect(r.produced, isTrue, reason: r.message);
    expect(r.score, isNotNull);
    // A night equal to the baseline carries ~zero load -> ~50.
    expect(r.score! >= 48 && r.score! <= 52, isTrue,
        reason: 'baseline-identical night should be ~50, got ${r.score}');
  });

  test('higher trough HR -> higher score (more load)', () {
    final history = matureBaseline();
    final identical = computeVascularLoad(
      history: history,
      tonight: baselineNight('id'),
      bankedValidCount: history.length,
    );
    final highHr = computeVascularLoad(
      history: history,
      tonight: baselineNight('hi-hr', hrP5: 70), // well above baseline 55
      bankedValidCount: history.length,
    );
    expect(highHr.produced, isTrue, reason: highHr.message);
    expect(highHr.score! > identical.score!, isTrue,
        reason: 'higher trough HR ${highHr.score} should exceed '
            'baseline-identical ${identical.score}');
  });

  test('lower HRV -> higher score (more load)', () {
    final history = matureBaseline();
    final identical = computeVascularLoad(
      history: history,
      tonight: baselineNight('id'),
      bankedValidCount: history.length,
    );
    final lowHrv = computeVascularLoad(
      history: history,
      tonight: baselineNight('lo-hrv', rmssdMedian: 20), // well below baseline 45
      bankedValidCount: history.length,
    );
    expect(lowHrv.produced, isTrue, reason: lowHrv.message);
    expect(lowHrv.score! > identical.score!, isTrue,
        reason: 'lower HRV ${lowHrv.score} should exceed '
            'baseline-identical ${identical.score}');
  });

  test('higher stress -> higher score (more load)', () {
    final history = matureBaseline();
    final identical = computeVascularLoad(
      history: history,
      tonight: baselineNight('id'),
      bankedValidCount: history.length,
    );
    final highStress = computeVascularLoad(
      history: history,
      tonight: baselineNight('hi-stress', stressMean: 70), // well above baseline 30
      bankedValidCount: history.length,
    );
    expect(highStress.produced, isTrue, reason: highStress.message);
    expect(highStress.score! > identical.score!, isTrue,
        reason: 'higher stress ${highStress.score} should exceed '
            'baseline-identical ${identical.score}');
  });
}

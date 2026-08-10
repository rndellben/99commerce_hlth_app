import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/providers/bp_calibration_providers.dart';
import 'package:hlth_app/features/blood_pressure/bp_controller.dart';
import 'package:hlth_app/features/blood_pressure/bp_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences keys for the offline-immediate UI cache. The band's
// flash is still the source of truth — these just let the screen render
// the last-known settings before (or instead of) connecting.
const _kPrefBpEnabled = 'bp_scheduled_enabled';
const _kPrefBpIntervalMin = 'bp_scheduled_interval_minutes';
const _kPrefBpHasSeenIntro = 'bp_has_seen_intro';

enum _CalibFlowResult { complete, skipped }

/// Blood Pressure detail screen.
///
/// Shows the latest stored BP reading as the headline, plus controls for
/// scheduled monitoring, on-demand measurement, and calibration.
class BloodPressureScreen extends ConsumerStatefulWidget {
  const BloodPressureScreen({super.key});

  @override
  ConsumerState<BloodPressureScreen> createState() =>
      _BloodPressureScreenState();
}

class _BloodPressureScreenState extends ConsumerState<BloodPressureScreen> {
  bool? _bpEnabled;
  int _bpIntervalMinutes = 60;
  bool _bpBusy = false;
  bool _measuring = false;

  bool _hasSeenIntro = true;
  bool _showPerformancePrompt = false;
  bool _hypertensionDismissed = false;

  // History view state (Day/Week/Month trend).
  Period _period = Period.day;
  DateTime _anchor = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  VoidCallback _shiftAnchor(int direction) {
    return () {
      setState(() {
        switch (_period) {
          case Period.day:
            _anchor = _anchor.add(Duration(days: direction));
            break;
          case Period.week:
            _anchor = _anchor.add(Duration(days: 7 * direction));
            break;
          case Period.month:
            _anchor =
                DateTime(_anchor.year, _anchor.month + direction, _anchor.day);
            break;
          case Period.threeMonths:
            _anchor = DateTime(
                _anchor.year, _anchor.month + (3 * direction), _anchor.day);
        }
      });
    };
  }

  @override
  void initState() {
    super.initState();
    _loadScheduled();
    _checkFirstTimeOpen();
  }

  Future<void> _checkFirstTimeOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kPrefBpHasSeenIntro) ?? false;
    if (mounted && !seen) setState(() => _hasSeenIntro = false);
  }

  Future<void> _markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefBpHasSeenIntro, true);
    if (mounted) setState(() => _hasSeenIntro = true);
  }

  Future<void> _startCalibrationFlow({bool skipBestPractices = false}) async {
    await _markIntroSeen();
    if (!mounted) return;
    setState(() => _showPerformancePrompt = false);
    final result = await Navigator.push<_CalibFlowResult>(
      context,
      MaterialPageRoute<_CalibFlowResult>(
        builder: (_) =>
            _BpCalibrationFlowPage(skipBestPractices: skipBestPractices),
      ),
    );
    if (!mounted) return;
    if (result == _CalibFlowResult.skipped) {
      setState(() => _showPerformancePrompt = true);
    }
  }

  Future<void> _loadScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedEnabled = prefs.getBool(_kPrefBpEnabled);
    final cachedInterval = prefs.getInt(_kPrefBpIntervalMin);
    if (mounted && (cachedEnabled != null || cachedInterval != null)) {
      setState(() {
        _bpEnabled = cachedEnabled;
        _bpIntervalMinutes = cachedInterval ?? 60;
      });
    }

    try {
      final cfg = await ref.read(bleServiceProvider).getBpScheduled();
      if (!mounted) return;
      final bandEnabled = cfg['isEnable'] as bool?;
      final bandInterval = (cfg['intervalMinutes'] as int?) ?? 60;
      setState(() {
        _bpEnabled = bandEnabled;
        _bpIntervalMinutes = bandInterval;
      });
      if (bandEnabled != null) {
        await prefs.setBool(_kPrefBpEnabled, bandEnabled);
      }
      await prefs.setInt(_kPrefBpIntervalMin, bandInterval);
    } catch (_) {
      // Disconnected — keep showing the cached values.
    }
  }

  Future<void> _writeCache(
      {required bool enabled, required int intervalMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefBpEnabled, enabled);
    await prefs.setInt(_kPrefBpIntervalMin, intervalMinutes);
  }

  Future<void> _toggleScheduled(bool enabled) async {
    final ble = ref.read(bleServiceProvider);
    final requestedInterval = _bpIntervalMinutes;
    setState(() {
      _bpBusy = true;
      _bpEnabled = enabled;
    });
    try {
      await ble.setBpScheduled(
        enabled: enabled,
        intervalMinutes: requestedInterval,
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      try {
        final cfg = await ble.getBpScheduled();
        if (!mounted) return;
        final trueEnabled = cfg['isEnable'] as bool? ?? enabled;
        final trueInterval =
            (cfg['intervalMinutes'] as int?) ?? requestedInterval;
        setState(() {
          _bpEnabled = trueEnabled;
          if (trueInterval > 0) _bpIntervalMinutes = trueInterval;
        });
        await _writeCache(
          enabled: trueEnabled,
          intervalMinutes: trueInterval > 0 ? trueInterval : requestedInterval,
        );
      } catch (_) {
        await _writeCache(
          enabled: enabled,
          intervalMinutes: requestedInterval,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _bpEnabled = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bpBusy = false);
    }
  }

  Future<void> _pickInterval() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Measurement interval',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final mins in const [15, 30, 60])
              ListTile(
                leading: Icon(
                  mins == _bpIntervalMinutes
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(_intervalLabel(mins)),
                onTap: () => Navigator.pop(ctx, mins),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _bpIntervalMinutes) return;
    setState(() => _bpIntervalMinutes = picked);
    if (_bpEnabled == true) {
      await _toggleScheduled(true);
    }
  }

  String _intervalLabel(int mins) {
    if (mins % 60 == 0) {
      final h = mins ~/ 60;
      return h == 1 ? 'Every hour' : 'Every $h hours';
    }
    return 'Every $mins minutes';
  }

  Future<void> _measureNow() async {
    final controller = ref.read(bpControllerProvider);
    setState(() => _measuring = true);
    try {
      final r = await controller.measure();
      if (!mounted) return;
      if (r.sbp <= 0 || r.dbp <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Band did not converge — try again with the ring snug'),
          ),
        );
        return;
      }
      await controller.storeBandReading(sbp: r.sbp, dbp: r.dbp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Measured: ${r.sbp}/${r.dbp} mmHg')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Measure failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestPair = ref.watch(calibratedLatestBpProvider).valueOrNull;
    final latestBp = latestPair?.reading;
    final activeCal = ref.watch(activeBpCalibrationProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    return MetricTrendScaffold(
      metricName: 'Blood Pressure',
      allowAddEdit: true,
      onAdd: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const _BpAddReadingPage()),
      ),
      onEdit: null,
      onShowDetails: () => context.push('/data-details?metric=blood-pressure'),
      aboutTitle: 'Blood Pressure',
      aboutText:
          'Blood pressure measures the force of blood against artery walls. A reading of 120/80 mmHg or below is generally considered healthy.',
      extraActions: const [],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Hypertension nudge
              if (!_hypertensionDismissed &&
                  latestPair != null &&
                  (latestPair.displaySbp >= 140 ||
                      latestPair.displayDbp >= 90))
                _HypertensionNudgeBanner(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const _BpHypertensionInfoPage()),
                  ),
                  onDismiss: () =>
                      setState(() => _hypertensionDismissed = true),
                ),

              // 2. Intro card
              if (!_hasSeenIntro && !_showPerformancePrompt)
                _BpIntroCard(
                  onCalibrate: () => _startCalibrationFlow(),
                  onSkip: () {
                    _markIntroSeen();
                    setState(() => _showPerformancePrompt = true);
                  },
                ),

              // 3. Performance prompt
              if (_showPerformancePrompt)
                _BpPerformancePromptCard(
                  onCalibrate: () =>
                      _startCalibrationFlow(skipBestPractices: true),
                  onSkip: () =>
                      setState(() => _showPerformancePrompt = false),
                ),

              const SizedBox(height: 24),
              const Icon(Icons.monitor_heart_outlined,
                  color: AppColors.bloodPressure, size: 48),
              const SizedBox(height: 16),
              Text(
                latestPair == null
                    ? '--'
                    : '${latestPair.displaySbp}/${latestPair.displayDbp}',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: AppColors.bloodPressure),
              ),
              Text(
                'mmHg',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                latestBp == null
                    ? (connected
                        ? 'No reading yet — measure or wait for scheduled run'
                        : 'Connect your band to see readings')
                    : (latestPair!.isCalibrated
                        ? 'Calibrated · last reading ${_timeAgo(latestBp.capturedAt)} · raw ${latestBp.systolicMmhg}/${latestBp.diastolicMmhg}'
                        : 'Uncalibrated · last reading ${_timeAgo(latestBp.capturedAt)}'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _CalibrationStatusCard(
                calibration: activeCal,
                onTap: () => _startCalibrationFlow(),
              ),
              const SizedBox(height: 16),
              _ScheduledCard(
                enabled: _bpEnabled,
                intervalLabel: _intervalLabel(_bpIntervalMinutes),
                busy: _bpBusy,
                onToggle: _toggleScheduled,
                onPickInterval: _pickInterval,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: !connected || _measuring ? null : _measureNow,
                  icon: _measuring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.bolt),
                  label:
                      Text(_measuring ? 'Measuring (~30s)...' : 'Measure Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bloodPressure,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!connected) ...[
                const SizedBox(height: 8),
                Text(
                  'Connect your band from the Settings tab to enable scheduling and Measure.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              // ── History (Day / Week / Month) BP trend ───────────────────
              // Fed by the band's autonomous hourly buffer + manual readings.
              PeriodToggle(
                value: _period,
                onChanged: (p) => setState(() {
                  _period = p;
                  _anchor = _today();
                }),
              ),
              const SizedBox(height: 16),
              DateSelector(
                period: _period,
                anchor: _anchor,
                onPrev: _shiftAnchor(-1),
                onNext: _shiftAnchor(1),
              ),
              const SizedBox(height: 16),
              if (_period == Period.day)
                _BpTrendDay(anchor: _anchor)
              else
                _BpTrendRange(period: _period, anchor: _anchor),
              const SizedBox(height: 24),
              DataDetailsCard(metric: 'blood-pressure'),
              const SizedBox(height: 16),
              Last7DaysTile(
                metric: 'blood-pressure',
                averageValue: null,
                unit: 'mmHg',
                color: AppColors.bloodPressure,
              ),
              const SizedBox(height: 16),
              AboutMetricSection(
                title: 'About Blood Pressure',
                body: 'Blood pressure measures the force of blood against artery walls. A reading of 120/80 mmHg or below is generally considered healthy.',
              ),
              const SizedBox(height: 16),
              const _DisclaimerCard(),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// BP trend (Day / Week / Month) — hourly buffer + manual readings
// ---------------------------------------------------------------------------

/// One calibrated point (local time + display sbp/dbp), applying the active
/// cuff calibration the SAME way the headline does so the trend matches.
typedef _BpPoint = ({DateTime at, int sbp, int dbp});

List<_BpPoint> _calibratedPoints(List<BpReading> readings, BpCalibration? cal) {
  final out = <_BpPoint>[];
  for (final r in readings) {
    // Same helper the headline uses — a local copy of the anchor logic is
    // how the chart and the headline drifted apart in the first place.
    final c = calibrateBpReading(reading: r, cal: cal);
    out.add((at: r.capturedAt.toLocal(), sbp: c.sbp, dbp: c.dbp));
  }
  return out;
}

double? _bpAvg(Iterable<int> xs) {
  final l = xs.toList();
  if (l.isEmpty) return null;
  return l.reduce((a, b) => a + b) / l.length;
}

int? _bpMedian(Iterable<int> xs) {
  final l = xs.toList()..sort();
  if (l.isEmpty) return null;
  final m = l.length ~/ 2;
  return l.length.isOdd ? l[m] : ((l[m - 1] + l[m]) / 2).round();
}

class _BpTrendDay extends ConsumerWidget {
  const _BpTrendDay({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bpReadingsForDateProvider(anchor));
    final cal = ref.watch(activeBpCalibrationProvider).valueOrNull;
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _BpTrendEmpty(message: 'Failed to load BP: $e'),
      data: (readings) {
        if (readings.isEmpty) {
          return const _BpTrendEmpty(
            message:
                'No BP readings for this day. The band measures hourly while '
                'worn — sync after wearing it, or tap Measure Now.',
          );
        }
        final pts = _calibratedPoints(readings, cal);
        final sysPoints = [
          for (final p in pts) TrendPoint(at: p.at, value: p.sbp.toDouble())
        ];
        final diaPoints = [
          for (final p in pts) TrendPoint(at: p.at, value: p.dbp.toDouble())
        ];
        final avgSys = _bpAvg(pts.map((p) => p.sbp));
        final avgDia = _bpAvg(pts.map((p) => p.dbp));
        final maxSys = pts.map((p) => p.sbp).reduce((a, b) => a > b ? a : b);
        final minDia = pts.map((p) => p.dbp).reduce((a, b) => a < b ? a : b);
        final labels = pts.length >= 2
            ? [hm(pts.first.at), hm(pts.last.at)]
            : const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Systolic across the day',
              subtitle: ymd(anchor),
              points: sysPoints,
              color: AppColors.bloodPressure,
              axis: const TrendAxis.bounded(
                min: 80,
                max: 180,
                referenceMin: 90,
                referenceMax: 120,
              ),
              bottomLabels: labels,
              showDots: true,
            ),
            const SizedBox(height: 16),
            TrendChartCard(
              title: 'Diastolic across the day',
              points: diaPoints,
              color: AppColors.bloodPressure.withValues(alpha: 0.6),
              axis: const TrendAxis.bounded(
                min: 40,
                max: 120,
                referenceMin: 60,
                referenceMax: 80,
              ),
              bottomLabels: labels,
              showDots: true,
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Average',
                  reference: 'Reference: ~120/80',
                  value: (avgSys == null || avgDia == null)
                      ? '--'
                      : '${avgSys.round()}/${avgDia.round()}',
                  valueUnit: 'mmHg',
                ),
                MetricTile(
                  label: 'Readings',
                  reference: 'hourly while worn',
                  value: readings.length.toString(),
                ),
                MetricTile(
                  label: 'Highest systolic',
                  reference: 'Reference: 90~120',
                  value: '$maxSys',
                  valueUnit: 'mmHg',
                  status: statusFor(
                    value: maxSys.toDouble(),
                    ok: const MetricRange(90, 120),
                    highIfAbove: 130,
                  ),
                ),
                MetricTile(
                  label: 'Lowest diastolic',
                  reference: 'Reference: 60~80',
                  value: '$minDia',
                  valueUnit: 'mmHg',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BpTrendRange extends ConsumerWidget {
  const _BpTrendRange({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final async = ref.watch(bpReadingsInRangeProvider(range));
    final cal = ref.watch(activeBpCalibrationProvider).valueOrNull;
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _BpTrendEmpty(message: 'Failed to load: $e'),
      data: (readings) {
        if (readings.isEmpty) {
          return const _BpTrendEmpty(
            message: 'No BP in this range. Wear the band to log hourly '
                'readings across the day.',
          );
        }
        // Group calibrated readings by local day → daily median sbp/dbp.
        final pts = _calibratedPoints(readings, cal);
        final byDay = <String, List<_BpPoint>>{};
        for (final p in pts) {
          final key = ymd(DateTime(p.at.year, p.at.month, p.at.day));
          (byDay[key] ??= []).add(p);
        }
        final dayKeys = byDay.keys.toList()..sort();
        final sysPoints = <TrendPoint>[];
        final diaPoints = <TrendPoint>[];
        final dailySys = <int>[];
        final dailyDia = <int>[];
        for (final k in dayKeys) {
          final ds = byDay[k]!;
          final medSys = _bpMedian(ds.map((p) => p.sbp))!;
          final medDia = _bpMedian(ds.map((p) => p.dbp))!;
          final noon = DateTime(ds.first.at.year, ds.first.at.month,
              ds.first.at.day, 12);
          sysPoints.add(TrendPoint(at: noon, value: medSys.toDouble()));
          diaPoints.add(TrendPoint(at: noon, value: medDia.toDouble()));
          dailySys.add(medSys);
          dailyDia.add(medDia);
        }
        final avgSys = _bpAvg(dailySys);
        final avgDia = _bpAvg(dailyDia);
        final span = period == Period.week
            ? 'this week'
            : period == Period.month
                ? 'this month'
                : '3 months';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Systolic (daily median) — $span',
              points: sysPoints,
              color: AppColors.bloodPressure,
              axis: const TrendAxis.bounded(
                min: 80,
                max: 180,
                referenceMin: 90,
                referenceMax: 120,
              ),
              bottomLabels: _bottomLabels(period, anchor),
              showDots: true,
            ),
            const SizedBox(height: 16),
            TrendChartCard(
              title: 'Diastolic (daily median) — $span',
              points: diaPoints,
              color: AppColors.bloodPressure.withValues(alpha: 0.6),
              axis: const TrendAxis.bounded(
                min: 40,
                max: 120,
                referenceMin: 60,
                referenceMax: 80,
              ),
              bottomLabels: _bottomLabels(period, anchor),
              showDots: true,
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Average',
                  reference: 'Reference: ~120/80',
                  value: (avgSys == null || avgDia == null)
                      ? '--'
                      : '${avgSys.round()}/${avgDia.round()}',
                  valueUnit: 'mmHg',
                ),
                MetricTile(
                  label: 'Days with data',
                  reference: '',
                  value: dayKeys.length.toString(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  BpDateRange _resolveRange(Period p, DateTime a) {
    switch (p) {
      case Period.day:
        final s = DateTime(a.year, a.month, a.day);
        return BpDateRange(fromDate: s, toDate: s);
      case Period.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return BpDateRange(
          fromDate: DateTime(monday.year, monday.month, monday.day),
          toDate: DateTime(sunday.year, sunday.month, sunday.day),
        );
      case Period.month:
        final first = DateTime(a.year, a.month, 1);
        final lastDay = DateTime(a.year, a.month + 1, 0);
        return BpDateRange(fromDate: first, toDate: lastDay);
      case Period.threeMonths:
        final first = DateTime(a.year, a.month - 2, 1);
        final lastDay = DateTime(a.year, a.month + 1, 0);
        return BpDateRange(fromDate: first, toDate: lastDay);
    }
  }

  List<String> _bottomLabels(Period period, DateTime anchor) {
    switch (period) {
      case Period.day:
        return const [];
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return List.generate(7, (i) => md(monday.add(Duration(days: i))));
      case Period.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        final days = next.difference(first).inDays;
        return [
          for (final day in [1, 7, 13, 19, 25, days])
            md(DateTime(first.year, first.month, day)),
        ];
      case Period.threeMonths:
        final first = DateTime(anchor.year, anchor.month - 2, 1);
        return [
          md(first),
          md(DateTime(first.year, first.month + 1, 1)),
          md(DateTime(first.year, first.month + 2, 1)),
        ];
    }
  }
}

class _BpTrendEmpty extends StatelessWidget {
  const _BpTrendEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_border,
              color: AppColors.bloodPressure, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Existing cards — kept unchanged
// ---------------------------------------------------------------------------

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({
    required this.enabled,
    required this.intervalLabel,
    required this.busy,
    required this.onToggle,
    required this.onPickInterval,
  });
  final bool? enabled;
  final String intervalLabel;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickInterval;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary:
                const Icon(Icons.schedule, color: AppColors.bloodPressure),
            title: const Text('Scheduled monitoring'),
            subtitle: Text(
              enabled == null
                  ? 'Connect the band to view status'
                  : enabled!
                      ? 'Auto-measures ${intervalLabel.toLowerCase()}, all day'
                      : 'Off — only manual readings will be saved',
            ),
            value: enabled ?? false,
            onChanged:
                (busy || enabled == null) ? null : (v) => onToggle(v),
          ),
          if (enabled != null)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Interval'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(intervalLabel,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                ],
              ),
              onTap: busy ? null : onPickInterval,
            ),
        ],
      ),
    );
  }
}

/// "Calibrated 132/85 · 2 days ago" status row — tap opens the calibration
/// flow. When no active calibration exists, prompts the user to add one.
class _CalibrationStatusCard extends StatelessWidget {
  const _CalibrationStatusCard({
    required this.calibration,
    required this.onTap,
  });
  final BpCalibration? calibration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cal = calibration;
    final title = cal == null
        ? 'Not calibrated'
        : 'Calibrated to ${cal.cuffSystolic}/${cal.cuffDiastolic}';
    final subtitle = cal == null
        ? 'Enter a cuff reading for personalized BP estimates'
        : 'Set ${_ago(cal.capturedAt)}'
            '${cal.bandWriteSucceeded ? '' : ' · band sync pending'}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(
          cal == null
              ? Icons.tune
              : (cal.bandWriteSucceeded
                  ? Icons.check_circle_outline
                  : Icons.sync_problem_outlined),
          color: cal == null
              ? AppColors.textSecondary
              : (cal.bandWriteSucceeded
                  ? AppColors.success
                  : AppColors.warning),
        ),
        title: Text(title),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(cal == null ? 'Calibrate' : 'Re-calibrate'),
        ),
        onTap: onTap,
      ),
    );
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inMinutes < 60) return 'just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}

// ---------------------------------------------------------------------------
// New widgets
// ---------------------------------------------------------------------------

class _BpIntroCard extends StatelessWidget {
  const _BpIntroCard({required this.onCalibrate, required this.onSkip});
  final VoidCallback onCalibrate;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.bloodPressure.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune,
                  color: AppColors.bloodPressure, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Improve accuracy with calibration',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A 2-minute cuff reading lets the band personalise its BP estimates to your baseline. Would you like to calibrate now?',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onCalibrate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bloodPressure,
                  ),
                  child: const Text('Yes, calibrate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BpPerformancePromptCard extends StatelessWidget {
  const _BpPerformancePromptCard(
      {required this.onCalibrate, required this.onSkip});
  final VoidCallback onCalibrate;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Better accuracy available',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Without calibration, readings are estimates only. Calibrating now takes about 2 minutes and significantly improves accuracy.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onCalibrate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bloodPressure,
                  ),
                  child: const Text('Calibrate now'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HypertensionNudgeBanner extends StatelessWidget {
  const _HypertensionNudgeBanner(
      {required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'High blood pressure detected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to learn more about hypertension and next steps.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.textTertiary),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Blood pressure readings from the band sensor are estimates and may not be suitable for medical diagnosis. Calibrate regularly and consult a healthcare professional for any concerns.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calibration flow page
// ---------------------------------------------------------------------------

enum _CalibStep { bestPractices, threeReadings, explainer }

class _BpCalibrationFlowPage extends ConsumerStatefulWidget {
  const _BpCalibrationFlowPage({this.skipBestPractices = false});
  final bool skipBestPractices;

  @override
  ConsumerState<_BpCalibrationFlowPage> createState() =>
      _BpCalibrationFlowPageState();
}

class _BpCalibrationFlowPageState
    extends ConsumerState<_BpCalibrationFlowPage> {
  late _CalibStep _step;
  bool _saving = false;

  final _sbpCtrl1 = TextEditingController();
  final _dbpCtrl1 = TextEditingController();
  final _sbpCtrl2 = TextEditingController();
  final _dbpCtrl2 = TextEditingController();
  final _sbpCtrl3 = TextEditingController();
  final _dbpCtrl3 = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _step = widget.skipBestPractices
        ? _CalibStep.threeReadings
        : _CalibStep.bestPractices;
  }

  @override
  void dispose() {
    _sbpCtrl1.dispose();
    _dbpCtrl1.dispose();
    _sbpCtrl2.dispose();
    _dbpCtrl2.dispose();
    _sbpCtrl3.dispose();
    _dbpCtrl3.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _restart() {
    _sbpCtrl1.clear();
    _dbpCtrl1.clear();
    _sbpCtrl2.clear();
    _dbpCtrl2.clear();
    _sbpCtrl3.clear();
    _dbpCtrl3.clear();
    _notesCtrl.clear();
    setState(() => _step = _CalibStep.bestPractices);
  }

  String? _validateField(String? raw, {required int min, required int max}) {
    if (raw == null || raw.isEmpty) return 'Required';
    final v = int.tryParse(raw);
    if (v == null) return 'Numbers only';
    if (v < min || v > max) return '$min–$max range';
    return null;
  }

  Future<void> _submitReadings() async {
    // Validate all 6 fields
    final pairs = [
      (_sbpCtrl1, _dbpCtrl1, 'Reading 1'),
      (_sbpCtrl2, _dbpCtrl2, 'Reading 2'),
      (_sbpCtrl3, _dbpCtrl3, 'Reading 3'),
    ];
    for (final (sbpCtrl, dbpCtrl, label) in pairs) {
      final sbpErr =
          _validateField(sbpCtrl.text, min: 70, max: 200);
      final dbpErr =
          _validateField(dbpCtrl.text, min: 40, max: 130);
      if (sbpErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label systolic: $sbpErr')),
        );
        return;
      }
      if (dbpErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label diastolic: $dbpErr')),
        );
        return;
      }
      final sbp = int.parse(sbpCtrl.text);
      final dbp = int.parse(dbpCtrl.text);
      if (sbp <= dbp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$label: systolic must be higher than diastolic')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(bpControllerProvider).saveCalibration(
        readings: [
          (sbp: int.parse(_sbpCtrl1.text), dbp: int.parse(_dbpCtrl1.text)),
          (sbp: int.parse(_sbpCtrl2.text), dbp: int.parse(_dbpCtrl2.text)),
          (sbp: int.parse(_sbpCtrl3.text), dbp: int.parse(_dbpCtrl3.text)),
        ],
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _step = _CalibStep.explainer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calibration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _stepTitle() {
    switch (_step) {
      case _CalibStep.bestPractices:
        return 'Before You Begin';
      case _CalibStep.threeReadings:
        return 'Enter Cuff Readings';
      case _CalibStep.explainer:
        return 'Calibration Complete';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _CalibStep.explainer,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(_stepTitle()),
          leading: _step != _CalibStep.explainer
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          automaticallyImplyLeading: false,
          actions: [
            if (_step == _CalibStep.threeReadings)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _CalibFlowResult.skipped),
                child: const Text('Skip'),
              ),
          ],
        ),
        body: switch (_step) {
          _CalibStep.bestPractices => _BestPracticesBody(
              onStart: () =>
                  setState(() => _step = _CalibStep.threeReadings),
              onSkip: () =>
                  Navigator.pop(context, _CalibFlowResult.skipped),
            ),
          _CalibStep.threeReadings => _ThreeReadingsBody(
              sbpCtrl1: _sbpCtrl1,
              dbpCtrl1: _dbpCtrl1,
              sbpCtrl2: _sbpCtrl2,
              dbpCtrl2: _dbpCtrl2,
              sbpCtrl3: _sbpCtrl3,
              dbpCtrl3: _dbpCtrl3,
              notesCtrl: _notesCtrl,
              saving: _saving,
              onSubmit: _submitReadings,
              onRestart: _restart,
            ),
          _CalibStep.explainer => _ExplainerBody(
              onContinue: () =>
                  Navigator.pop(context, _CalibFlowResult.complete),
            ),
        },
      ),
    );
  }
}

class _BestPracticesBody extends StatelessWidget {
  const _BestPracticesBody(
      {required this.onStart, required this.onSkip});
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.chair_outlined, 'Rest for 5 minutes before measuring'),
      (Icons.accessibility_new_outlined,
          'Sit upright with your feet flat on the floor'),
      (Icons.favorite_border, 'Place your arm at heart level'),
      (Icons.speaker_notes_off_outlined,
          'Do not talk during the measurement'),
      (Icons.repeat_outlined, 'Take 3 readings, 1 minute apart'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.health_and_safety_outlined,
              color: AppColors.bloodPressure, size: 64),
          const SizedBox(height: 20),
          Text(
            'Best practices for accurate readings',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          for (final (icon, text) in tips) ...[
            Row(
              children: [
                Icon(icon,
                    color: AppColors.bloodPressure, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure),
              child: const Text('Start calibration'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeReadingsBody extends StatelessWidget {
  const _ThreeReadingsBody({
    required this.sbpCtrl1,
    required this.dbpCtrl1,
    required this.sbpCtrl2,
    required this.dbpCtrl2,
    required this.sbpCtrl3,
    required this.dbpCtrl3,
    required this.notesCtrl,
    required this.saving,
    required this.onSubmit,
    required this.onRestart,
  });
  final TextEditingController sbpCtrl1;
  final TextEditingController dbpCtrl1;
  final TextEditingController sbpCtrl2;
  final TextEditingController dbpCtrl2;
  final TextEditingController sbpCtrl3;
  final TextEditingController dbpCtrl3;
  final TextEditingController notesCtrl;
  final bool saving;
  final VoidCallback onSubmit;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter 3 cuff readings',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Take readings 1 minute apart. The average will be used to calibrate your band.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _ReadingRow(
              label: 'Reading 1',
              sbpCtrl: sbpCtrl1,
              dbpCtrl: dbpCtrl1),
          const SizedBox(height: 16),
          _ReadingRow(
              label: 'Reading 2',
              sbpCtrl: sbpCtrl2,
              dbpCtrl: dbpCtrl2),
          const SizedBox(height: 16),
          _ReadingRow(
              label: 'Reading 3',
              sbpCtrl: sbpCtrl3,
              dbpCtrl: dbpCtrl3),
          const SizedBox(height: 16),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. after lunch, left arm',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white)),
                    )
                  : const Text('Submit readings'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Restart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow(
      {required this.label,
      required this.sbpCtrl,
      required this.dbpCtrl});
  final String label;
  final TextEditingController sbpCtrl;
  final TextEditingController dbpCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: sbpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Systolic',
                  suffixText: 'mmHg',
                  hintText: '120',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: dbpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Diastolic',
                  suffixText: 'mmHg',
                  hintText: '80',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExplainerBody extends StatelessWidget {
  const _ExplainerBody({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.check_circle_outline,
              color: AppColors.success, size: 72),
          const SizedBox(height: 20),
          Text(
            'Your band is calibrated',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'The band\'s blood pressure sensor estimates are now anchored to your cuff reading. Going forward, readings will be personalized to your baseline.\n\nRecalibrate every 2–4 weeks, or whenever you notice drift from a trusted cuff.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure),
              child: const Text('Continue to Blood Pressure'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Reading page
// ---------------------------------------------------------------------------

class _BpAddReadingPage extends ConsumerStatefulWidget {
  const _BpAddReadingPage();

  @override
  ConsumerState<_BpAddReadingPage> createState() =>
      _BpAddReadingPageState();
}

class _BpAddReadingPageState extends ConsumerState<_BpAddReadingPage> {
  final _sbpCtrl = TextEditingController();
  final _dbpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _sbpCtrl.dispose();
    _dbpCtrl.dispose();
    _pulseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validateField(String? raw, {required int min, required int max}) {
    if (raw == null || raw.isEmpty) return 'Required';
    final v = int.tryParse(raw);
    if (v == null) return 'Numbers only';
    if (v < min || v > max) return '$min–$max range';
    return null;
  }

  Future<void> _save() async {
    final sbpErr = _validateField(_sbpCtrl.text, min: 70, max: 200);
    if (sbpErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Systolic: $sbpErr')));
      return;
    }
    final dbpErr = _validateField(_dbpCtrl.text, min: 40, max: 130);
    if (dbpErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Diastolic: $dbpErr')));
      return;
    }
    final sbp = int.parse(_sbpCtrl.text);
    final dbp = int.parse(_dbpCtrl.text);
    if (sbp <= dbp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Systolic must be higher than diastolic')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(bpControllerProvider).storeManualReading(
            sbp: sbp,
            dbp: dbp,
            pulseBpm: int.tryParse(_pulseCtrl.text),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Add Reading'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sbpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Systolic *',
                      suffixText: 'mmHg',
                      hintText: '120',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dbpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diastolic *',
                      suffixText: 'mmHg',
                      hintText: '80',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pulseCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pulse (optional)',
                suffixText: 'bpm',
                hintText: '72',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. after lunch, left arm',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white)),
                    )
                  : const Text('Save reading'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hypertension info page
// ---------------------------------------------------------------------------

class _BpHypertensionInfoPage extends StatelessWidget {
  const _BpHypertensionInfoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('High Blood Pressure'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 56),
            const SizedBox(height: 16),
            Text(
              'Understanding High Blood Pressure',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Your recent reading shows blood pressure at or above 140/90 mmHg, which is classified as Stage 2 Hypertension.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _InfoSection(
              title: 'BP Categories',
              rows: const [
                ('Normal', '< 120/80 mmHg'),
                ('Elevated', '120–129/<80 mmHg'),
                ('Stage 1 Hypertension', '130–139/80–89 mmHg'),
                ('Stage 2 Hypertension', '≥ 140/90 mmHg'),
                ('Hypertensive Crisis', '> 180/120 mmHg'),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              title: 'What to do',
              rows: const [
                ('Reduce sodium intake', ''),
                ('Exercise regularly', ''),
                ('Manage stress', ''),
                ('Avoid tobacco and limit alcohol', ''),
                ('See a healthcare professional', ''),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'This information is for educational purposes only and does not constitute medical advice. Always consult a qualified healthcare professional regarding your blood pressure.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(label,
                          style: Theme.of(context).textTheme.bodySmall)),
                  if (value.isNotEmpty)
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

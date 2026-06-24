import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/features/sleep/sleep_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';

/// Sleep detail screen mirroring QWatch Pro's Day / Week / Month layout.
///
/// Day view: bedtime~wake range, hypnogram, metric cards (total sleep,
/// deep continuity score, % deep, % light, per-stage durations).
/// Week / Month: stacked-bar series of nightly sleep over the period,
/// plus averages.
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  Period _period = Period.day;
  // Anchor date for the selected period. For Day view this is the wake
  // date (the day the user perceives as "today's sleep"); for Week it's
  // any day in the week; for Month it's any day in the month.
  DateTime _anchor = _today();
  bool _syncing = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBand());
  }

  /// Pulls the sleep day(s) that the current view needs from the band.
  ///
  /// Day: just the one day-offset. Week: offsets covering Mon-Sun.
  /// Month: offsets covering the visible month (capped at SDK's 7-day
  /// window — H59 only stores ~7 days of sleep history, older sessions
  /// live in our local SQLite from prior syncs).
  Future<void> _refreshFromBand() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device == null) return; // not paired — silently skip
      final sync = ref.read(syncServiceProvider);
      final offsets = _offsetsForView();
      final results = await sync.syncSleepRange(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
        offsets: offsets,
      );
      if (!mounted) return;
      final total = results.fold<int>(0, (a, r) => a + r.count);
      // Invalidate the day-anchored provider so the new session shows up.
      ref.invalidate(sleepSessionForDateProvider);
      ref.invalidate(sleepSessionsInRangeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total == 0
              ? 'No new sleep data on band'
              : 'Synced ${offsets.length} day(s) of sleep'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// SDK §2.3.3 supports dayOffset 0..7. We clamp to that window —
  /// older days that are no longer on the band still surface from local
  /// SQLite via the repo.
  Iterable<int> _offsetsForView() {
    final today = _today();
    switch (_period) {
      case Period.day:
        final delta = today.difference(_anchor).inDays;
        return [delta.clamp(0, 7)];
      case Period.week:
        final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          return today.difference(d).inDays.clamp(0, 7);
        }).toSet();
      case Period.month:
        // The band only retains ~7 days. Pull what it has; older days
        // come from local SQLite.
        return List.generate(8, (i) => i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Sleep'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _syncing ? null : _refreshFromBand,
            tooltip: 'Sync from band',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFromBand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                if (_period == Period.day) _DayView(anchor: _anchor),
                if (_period == Period.week)
                  _WeekOrMonthView(period: _period, anchor: _anchor),
                if (_period == Period.month)
                  _WeekOrMonthView(period: _period, anchor: _anchor),
              ],
            ),
          ),
        ),
      ),
    );
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
            _anchor = DateTime(
              _anchor.year,
              _anchor.month + direction,
              _anchor.day,
            );
            break;
        }
      });
      // Pull the freshly-selected day from the band if it's within
      // reach. Older days fall back to local SQLite — no BLE call.
      _refreshFromBand();
    };
  }
}

// ─── Day view ──────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sleepSessionForDateProvider(anchor));
    return sessionAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load sleep: $e'),
      data: (session) {
        if (session == null) {
          return const _EmptyState(
              message: 'No sleep data yet. Wear the band overnight to see your sleep stages.');
        }
        return _DaySessionContent(session: session);
      },
    );
  }
}

class _DaySessionContent extends ConsumerWidget {
  const _DaySessionContent({required this.session});
  final SleepSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epochsAsync = ref.watch(sleepEpochsProvider(session.id));
    final totalMin = session.totalMin;
    final deepPct = totalMin > 0 ? (session.deepMin * 100 / totalMin) : 0.0;
    final lightPct = totalMin > 0 ? (session.lightMin * 100 / totalMin) : 0.0;
    final continuity = _deepContinuityScore(session.deepMin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            '${hm(session.startedAt.toLocal())} ~ ${hm(session.endedAt.toLocal())}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _HypnogramCard(session: session, epochsAsync: epochsAsync),
        const SizedBox(height: 16),
        MetricGrid(
          tiles: [
            MetricTile(
              label: 'Total sleep time',
              reference: 'Reference: 6~10h',
              value: _hmDuration(totalMin),
              status: statusFor(
                value: totalMin.toDouble(),
                ok: const MetricRange(360, 600),
              ),
            ),
            MetricTile(
              label: 'Deep sleep continuity',
              reference: 'Reference: 70~100',
              value: continuity.toString(),
              valueUnit: 'Score',
              status: statusFor(
                value: continuity.toDouble(),
                ok: const MetricRange(70, 100),
              ),
            ),
            MetricTile(
              label: 'Percentage of deep sleep',
              reference: 'Reference: 20~60%',
              value: deepPct.toStringAsFixed(0),
              valueUnit: '%',
              status: statusFor(
                value: deepPct,
                ok: const MetricRange(20, 60),
              ),
            ),
            MetricTile(
              label: 'Percentage of core sleep',
              reference: 'Reference: 50%',
              value: lightPct.toStringAsFixed(0),
              valueUnit: '%',
              status: statusFor(
                value: lightPct,
                ok: const MetricRange(30, 60),
                highIfAbove: 60,
              ),
            ),
            MetricTile(
              label: 'Total deep sleep duration',
              reference: '',
              value: _hmDuration(session.deepMin),
            ),
            MetricTile(
              label: 'Total core sleep duration',
              reference: '',
              value: _hmDuration(session.lightMin),
            ),
            MetricTile(
              label: 'Total time awake',
              reference: '',
              value: _hmDuration(session.awakeMin),
            ),
            MetricTile(
              label: 'Total REM duration',
              reference: '',
              value: _hmDuration(session.remMin),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DisclaimerCard(),
      ],
    );
  }
}

// QWatch's deep-continuity score reverse-engineered from "1h50min deep
// → score 91" ≈ 110 / 120 * 100. Documented as sleep-deep-continuity-v1.
int _deepContinuityScore(int deepMin) {
  final raw = (deepMin / 120 * 100).round();
  return raw.clamp(0, 100);
}

String _hmDuration(int minutes) {
  if (minutes <= 0) return '0h 0min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h ${m}min';
}

// ─── Hypnogram card ────────────────────────────────────────────────────────

class _HypnogramCard extends StatelessWidget {
  const _HypnogramCard({required this.session, required this.epochsAsync});
  final SleepSession session;
  final AsyncValue<List<SleepEpoch>> epochsAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _dominantLabel(session),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _dominantValue(session),
                style: const TextStyle(
                  color: AppColors.sleep,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'min',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _LegendDot(color: _StageColors.deep, label: 'Deep sleep'),
              _LegendDot(color: _StageColors.light, label: 'Core sleep'),
              _LegendDot(color: _StageColors.rem, label: 'Rapid Eye Movement'),
              _LegendDot(color: _StageColors.awake, label: 'Awake'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: epochsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text(
                  'Hypnogram unavailable',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              data: (epochs) => _Hypnogram(
                sessionStart: session.startedAt.toLocal(),
                sessionEnd: session.endedAt.toLocal(),
                epochs: epochs,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hm(session.startedAt.toLocal()),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              Text(hm(session.endedAt.toLocal()),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // Show whichever stage dominated last night (QWatch shows "Light sleep 33min"
  // in the header). We pick the largest single-stage block — usually light.
  String _dominantLabel(SleepSession s) {
    final (label, _) = _dominant(s);
    return label;
  }

  String _dominantValue(SleepSession s) {
    final (_, value) = _dominant(s);
    return value.toString();
  }

  (String, int) _dominant(SleepSession s) {
    final stages = <String, int>{
      'Core sleep': s.lightMin,
      'Deep sleep': s.deepMin,
      'Rapid Eye Movement': s.remMin,
      'Awake': s.awakeMin,
    };
    final entry =
        stages.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (entry.key, entry.value);
  }
}

class _StageColors {
  static const deep = Color(0xFF6B4CDB);
  static const light = Color(0xFFD5C8FF);
  static const rem = Color(0xFFB888FF);
  static const awake = Color(0xFFFFB47A);
}

Color _colorFor(SleepStage stage) => switch (stage) {
      SleepStage.deep => _StageColors.deep,
      SleepStage.light => _StageColors.light,
      SleepStage.rem => _StageColors.rem,
      SleepStage.awake => _StageColors.awake,
      SleepStage.noSleep => Colors.transparent,
      SleepStage.unweared => Colors.transparent,
    };

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Hypnogram strip — one vertical bar per epoch, height proportional to
/// the stage's "depth" so deep sits at the top, awake at the bottom.
class _Hypnogram extends StatelessWidget {
  const _Hypnogram({
    required this.sessionStart,
    required this.sessionEnd,
    required this.epochs,
  });

  final DateTime sessionStart;
  final DateTime sessionEnd;
  final List<SleepEpoch> epochs;

  @override
  Widget build(BuildContext context) {
    if (epochs.isEmpty) {
      return const Center(
        child: Text(
          'Epoch data not available — only session totals',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }
    return CustomPaint(
      painter: _HypnogramPainter(
        sessionStart: sessionStart,
        sessionEnd: sessionEnd,
        epochs: epochs,
      ),
      size: Size.infinite,
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  _HypnogramPainter({
    required this.sessionStart,
    required this.sessionEnd,
    required this.epochs,
  });

  final DateTime sessionStart;
  final DateTime sessionEnd;
  final List<SleepEpoch> epochs;

  @override
  void paint(Canvas canvas, Size size) {
    final totalSec = sessionEnd.difference(sessionStart).inSeconds;
    if (totalSec <= 0) return;

    // Baseline strip across the full width (light-lavender backdrop —
    // matches QWatch's "always-there" base line).
    final baselinePaint = Paint()..color = _StageColors.light.withValues(alpha: 0.35);
    final baselineRect = Rect.fromLTWH(
      0,
      size.height * 0.55,
      size.width,
      size.height * 0.15,
    );
    canvas.drawRect(baselineRect, baselinePaint);

    for (final e in epochs) {
      final color = _colorFor(e.stage);
      if (color == Colors.transparent) continue;
      final startSec =
          e.startedAt.toLocal().difference(sessionStart).inSeconds;
      final widthSec = (e.durationMin * 60).clamp(1, 1 << 30);
      final x = (startSec / totalSec) * size.width;
      final w = (widthSec / totalSec) * size.width;
      final (top, height) = _barGeometry(e.stage, size.height);
      final rect = Rect.fromLTWH(x, top, w.clamp(1.0, size.width), height);
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  // Deep bars sit at the top and tall; light is the mid-base baseline;
  // REM is between deep and light; awake is short and at the bottom.
  (double top, double height) _barGeometry(SleepStage stage, double h) {
    switch (stage) {
      case SleepStage.deep:
        return (h * 0.05, h * 0.65);
      case SleepStage.rem:
        return (h * 0.20, h * 0.50);
      case SleepStage.light:
        return (h * 0.55, h * 0.15);
      case SleepStage.awake:
        return (h * 0.80, h * 0.20);
      case SleepStage.noSleep:
      case SleepStage.unweared:
        return (0, 0);
    }
  }

  @override
  bool shouldRepaint(covariant _HypnogramPainter old) =>
      old.sessionStart != sessionStart ||
      old.sessionEnd != sessionEnd ||
      old.epochs.length != epochs.length;
}

// ─── Week / Month views ────────────────────────────────────────────────────

class _WeekOrMonthView extends ConsumerWidget {
  const _WeekOrMonthView({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final async = ref.watch(sleepSessionsInRangeProvider(range));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load: $e'),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const _EmptyState(
              message: 'No sleep recorded in this period.');
        }
        return _RangeContent(
          period: period,
          anchor: anchor,
          range: range,
          sessions: sessions,
        );
      },
    );
  }

  SleepRange _resolveRange(Period p, DateTime a) {
    switch (p) {
      case Period.day:
        final start = DateTime(a.year, a.month, a.day);
        return SleepRange(
          from: start.subtract(const Duration(hours: 18)).toUtc(),
          to: start.add(const Duration(hours: 12)).toUtc(),
        );
      case Period.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        final from = DateTime(monday.year, monday.month, monday.day)
            .subtract(const Duration(hours: 18));
        final sundayEnd = monday.add(const Duration(days: 7));
        return SleepRange(from: from.toUtc(), to: sundayEnd.toUtc());
      case Period.month:
        final first = DateTime(a.year, a.month, 1);
        final next = DateTime(a.year, a.month + 1, 1);
        return SleepRange(
          from: first.subtract(const Duration(hours: 18)).toUtc(),
          to: next.toUtc(),
        );
    }
  }
}

class _RangeContent extends StatelessWidget {
  const _RangeContent({
    required this.period,
    required this.anchor,
    required this.range,
    required this.sessions,
  });
  final Period period;
  final DateTime anchor;
  final SleepRange range;
  final List<SleepSession> sessions;

  @override
  Widget build(BuildContext context) {
    final avgTotal = _avg(sessions.map((s) => s.totalMin.toDouble()));
    final avgDeepPct = _avg(sessions
        .where((s) => s.totalMin > 0)
        .map((s) => s.deepMin * 100 / s.totalMin));
    final avgLightPct = _avg(sessions
        .where((s) => s.totalMin > 0)
        .map((s) => s.lightMin * 100 / s.totalMin));
    final avgContinuity = _avg(
        sessions.map((s) => _deepContinuityScore(s.deepMin).toDouble()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RangeBarChart(period: period, anchor: anchor, sessions: sessions),
        const SizedBox(height: 16),
        MetricGrid(tiles: [
          MetricTile(
            label: 'Average sleep duration',
            reference: 'Reference: 6~10h',
            value: avgTotal == null ? '--' : _hmDuration(avgTotal.round()),
            status: avgTotal == null
                ? MetricStatus.none
                : statusFor(value: avgTotal, ok: const MetricRange(360, 600)),
          ),
          MetricTile(
            label: 'Deep sleep continuity',
            reference: 'Reference: 70~100',
            value: avgContinuity == null
                ? '--'
                : avgContinuity.toStringAsFixed(0),
            valueUnit: 'Score',
            status: avgContinuity == null
                ? MetricStatus.none
                : statusFor(
                    value: avgContinuity, ok: const MetricRange(70, 100)),
          ),
          MetricTile(
            label: 'Average deep sleep percentage',
            reference: 'Reference: 20~60%',
            value: avgDeepPct == null ? '--' : avgDeepPct.toStringAsFixed(0),
            valueUnit: '%',
            status: avgDeepPct == null
                ? MetricStatus.none
                : statusFor(value: avgDeepPct, ok: const MetricRange(20, 60)),
          ),
          MetricTile(
            label: 'Average core sleep percentage',
            reference: 'Reference: 50%',
            value: avgLightPct == null ? '--' : avgLightPct.toStringAsFixed(0),
            valueUnit: '%',
            status: avgLightPct == null
                ? MetricStatus.none
                : statusFor(
                    value: avgLightPct,
                    ok: const MetricRange(30, 60),
                    highIfAbove: 60),
          ),
        ]),
        const SizedBox(height: 16),
        _DisclaimerCard(),
      ],
    );
  }
}

double? _avg(Iterable<double> values) {
  final list = values.where((v) => v.isFinite).toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

class _RangeBarChart extends StatelessWidget {
  const _RangeBarChart({
    required this.period,
    required this.anchor,
    required this.sessions,
  });
  final Period period;
  final DateTime anchor;
  final List<SleepSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _LegendDot(color: _StageColors.deep, label: 'Deep sleep'),
              _LegendDot(color: _StageColors.light, label: 'Core sleep'),
              _LegendDot(color: _StageColors.rem, label: 'Rapid Eye Movement'),
              _LegendDot(color: _StageColors.awake, label: 'Awake'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _StackedBarPainter(
                period: period,
                anchor: anchor,
                sessions: sessions,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          _AxisLabels(period: period, anchor: anchor),
        ],
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({
    required this.period,
    required this.anchor,
    required this.sessions,
  });
  final Period period;
  final DateTime anchor;
  final List<SleepSession> sessions;

  @override
  void paint(Canvas canvas, Size size) {
    if (sessions.isEmpty) return;
    final byDay = <String, SleepSession>{};
    for (final s in sessions) {
      final wake = s.endedAt.toLocal();
      byDay[ymd(DateTime(wake.year, wake.month, wake.day))] = s;
    }
    if (byDay.isEmpty) return;

    final maxMin = sessions
        .map((s) => s.totalMin)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(60, 1 << 30);

    final slots = _slotKeys();
    final n = slots.length;
    if (n == 0) return;
    final gap = 4.0;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(2.0, 40.0);

    for (var i = 0; i < n; i++) {
      final s = byDay[slots[i]];
      if (s == null) continue;
      final x = i * (barW + gap);
      _drawStack(canvas, x, barW, size.height, s, maxMin.toDouble());
    }
  }

  void _drawStack(Canvas canvas, double x, double w, double h, SleepSession s,
      double maxMin) {
    var cursorBottom = h;
    void block(int minutes, Color color) {
      if (minutes <= 0) return;
      final segH = (minutes / maxMin) * h;
      final rect = Rect.fromLTWH(x, cursorBottom - segH, w, segH);
      canvas.drawRect(rect, Paint()..color = color);
      cursorBottom -= segH;
    }

    // Order bottom→top: deep, light, rem, awake (QWatch convention).
    block(s.deepMin, _StageColors.deep);
    block(s.lightMin, _StageColors.light);
    block(s.remMin, _StageColors.rem);
    block(s.awakeMin, _StageColors.awake);
  }

  List<String> _slotKeys() {
    switch (period) {
      case Period.day:
        return [ymd(anchor)];
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return List.generate(
            7, (i) => ymd(monday.add(Duration(days: i))));
      case Period.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        final days = next.difference(first).inDays;
        return List.generate(
            days, (i) => ymd(first.add(Duration(days: i))));
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) =>
      old.period != period || old.sessions.length != sessions.length;
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    switch (period) {
      case Period.day:
        return const SizedBox.shrink();
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final d = monday.add(Duration(days: i));
            return Text(md(d),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11));
          }),
        );
      case Period.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        final days = next.difference(first).inDays;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in [1, 7, 13, 19, 25, days])
              Text(
                md(DateTime(first.year, first.month, day)),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
          ],
        );
    }
  }
}

// ─── Empty state + disclaimer ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.bedtime, color: AppColors.sleep, size: 28),
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
      child: const Text(
        'The device analyzes changes in physical activity to estimate your sleep time and sleep status. '
        'Sleep data can help you understand and manage your sleep habits. '
        'This feature is not designed for medical use — consult a healthcare professional for any concerns.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }
}

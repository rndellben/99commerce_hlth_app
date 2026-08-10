import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Data Details screen — month summary with day-level drill-down.
///
/// Reusable template used by all metric trend views via
/// `/data-details?metric=<name>`.
///
/// Navigation:
///   Month Summary → back → Trend view  (pop)
///   Month Summary → tap day → Day readings view (push)
class DataDetailsScreen extends StatefulWidget {
  const DataDetailsScreen({super.key, required this.metric});
  final String metric; // e.g. 'heart-rate', 'hrv', 'spo2'

  @override
  State<DataDetailsScreen> createState() => _DataDetailsScreenState();
}

class _DataDetailsScreenState extends State<DataDetailsScreen> {
  DateTime _month = _thisMonth();

  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_metricDisplayName(widget.metric)),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MonthSelector(
              month: _month,
              onPrev: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1, 1);
              }),
              onNext: _canGoNext()
                  ? () => setState(() {
                        _month =
                            DateTime(_month.year, _month.month + 1, 1);
                      })
                  : null,
            ),
            Expanded(
              child: _MonthCalendar(
                month: _month,
                metric: widget.metric,
                onDayTap: (day) => _showDayReadings(context, day),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canGoNext() {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month, 1));
  }

  void _showDayReadings(BuildContext context, DateTime day) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _DayReadingsScreen(metric: widget.metric, day: day),
      ),
    );
  }

  String _metricDisplayName(String metric) => switch (metric) {
        'heart-rate' => 'Heart Rate',
        'hrv' => 'HRV',
        'spo2' => 'SpO2',
        'sleep' => 'Sleep',
        'stress' => 'Stress',
        'blood-pressure' => 'Blood Pressure',
        'recovery' => 'Stability',
        'cardio-load' => 'Cardio Load',
        _ => metric,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Month selector header
// ─────────────────────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final label =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left,
                color: AppColors.textSecondary),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right,
              color: onNext != null
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.metric,
    required this.onDayTap,
  });
  final DateTime month;
  final String metric;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday =
        DateTime(month.year, month.month, 1).weekday; // 1=Mon … 7=Sun
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: (firstWeekday - 1) + daysInMonth,
      itemBuilder: (context, index) {
        // Leading empty cells for days before the 1st.
        if (index < firstWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstWeekday - 1) + 1;
        final date = DateTime(month.year, month.month, day);
        final isFuture = date.isAfter(today);
        return GestureDetector(
          onTap: isFuture ? null : () => onDayTap(date),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFuture
                  ? Colors.transparent
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isFuture
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day readings view (pushed from calendar day tap)
// ─────────────────────────────────────────────────────────────────────────────

class _DayReadingsScreen extends ConsumerWidget {
  const _DayReadingsScreen({
    required this.metric,
    required this.day,
  });
  final String metric;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(label),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: _DayReadingsBody(metric: metric, day: day),
      ),
    );
  }
}

class _DayReadingsBody extends ConsumerWidget {
  const _DayReadingsBody({required this.metric, required this.day});
  final String metric;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final userId = ActiveSession.defaultUserId;

    return FutureBuilder<List<_ReadingRow>>(
      future: _fetchReadings(ref, userId, dayStart, dayEnd),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Failed to load readings: ${snap.error}',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_metricIcon(metric),
                      color: _metricColor(metric), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'No ${_metricDisplayName(metric).toLowerCase()} readings for this day.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: rows.length + 1, // +1 for summary header
          separatorBuilder: (_, __) => const SizedBox(height: 1),
          itemBuilder: (context, i) {
            if (i == 0) return _SummaryHeader(metric: metric, rows: rows);
            final row = rows[i - 1];
            return _ReadingTile(
              time: row.time,
              value: row.value,
              unit: row.unit,
              color: _metricColor(metric),
            );
          },
        );
      },
    );
  }

  Future<List<_ReadingRow>> _fetchReadings(
      WidgetRef ref, String userId, DateTime from, DateTime to) async {
    final fromUtc = from.toUtc();
    final toUtc = to.toUtc();

    switch (metric) {
      case 'heart-rate':
        final repo = ref.read(hrRepositoryProvider);
        final samples =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return samples
            .map((s) => _ReadingRow(
                  time: s.capturedAt.toLocal(),
                  value: '${s.bpm}',
                  unit: 'bpm',
                ))
            .toList();

      case 'hrv':
        final repo = ref.read(hrvRepositoryProvider);
        final samples =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return samples
            .map((s) => _ReadingRow(
                  time: s.capturedAt.toLocal(),
                  value: '${s.rmssdMs}',
                  unit: 'ms',
                ))
            .toList();

      case 'spo2':
        final repo = ref.read(spo2RepositoryProvider);
        final samples =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return samples
            .map((s) => _ReadingRow(
                  time: s.capturedAt.toLocal(),
                  value: '${s.pctMin}–${s.pctMax}',
                  unit: '%',
                ))
            .toList();

      case 'blood-pressure':
        final repo = ref.read(bpRepositoryProvider);
        final samples =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return samples
            .map((s) => _ReadingRow(
                  time: s.capturedAt.toLocal(),
                  value: '${s.systolicMmhg}/${s.diastolicMmhg}',
                  unit: 'mmHg',
                ))
            .toList();

      case 'stress':
        final repo = ref.read(stressRepositoryProvider);
        final samples =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return samples
            .map((s) => _ReadingRow(
                  time: s.capturedAt.toLocal(),
                  value: '${s.stressScore}',
                  unit: '',
                ))
            .toList();

      case 'sleep':
        final repo = ref.read(sleepRepositoryProvider);
        final sessions =
            await repo.getInRange(userId: userId, from: fromUtc, to: toUtc);
        return sessions
            .map((s) => _ReadingRow(
                  time: s.startedAt.toLocal(),
                  value: _formatMinutes(s.totalMin),
                  unit: '',
                  subtitle:
                      'Deep ${s.deepMin}m · Light ${s.lightMin}m · REM ${s.remMin}m · Awake ${s.awakeMin}m',
                ))
            .toList();

      // Daily scores: one persisted row per day in the scores table. The
      // "reading" for a day is that day's score + label (e.g. "49.3 /100 —
      // Moderate"), timestamped by when it was computed.
      case 'recovery':
        return _scoreRows(ref, userId, ScoreType.recovery);

      case 'cardio-load':
        return _scoreRows(ref, userId, ScoreType.cardioLoad);

      default:
        return [];
    }
  }

  Future<List<_ReadingRow>> _scoreRows(
      WidgetRef ref, String userId, ScoreType type) async {
    final rows = await ref
        .read(scoreRepositoryProvider)
        .getHistory(userId: userId, scoreType: type);
    return rows
        .where((s) =>
            s.computedForDate.year == day.year &&
            s.computedForDate.month == day.month &&
            s.computedForDate.day == day.day)
        .map((s) => _ReadingRow(
              time: s.computedAt.toLocal(),
              value: s.score.toStringAsFixed(1),
              unit:
                  '/100${s.label != null ? ' — ${s.label}' : ''}'
                  '${s.provisional ? ' (calibrating)' : ''}',
            ))
        .toList();
  }

  String _formatMinutes(int? min) {
    if (min == null || min <= 0) return '--';
    final h = min ~/ 60;
    final m = min % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reading data model
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingRow {
  const _ReadingRow({
    required this.time,
    required this.value,
    required this.unit,
    this.subtitle,
  });
  final DateTime time;
  final String value;
  final String unit;
  final String? subtitle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.metric, required this.rows});
  final String metric;
  final List<_ReadingRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(_metricIcon(metric), color: _metricColor(metric), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _metricDisplayName(metric),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${rows.length} reading${rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual reading tile
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.time,
    required this.value,
    required this.unit,
    required this.color,
  });
  final DateTime time;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              timeLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: ' $unit',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric helpers
// ─────────────────────────────────────────────────────────────────────────────

String _metricDisplayName(String metric) => switch (metric) {
      'heart-rate' => 'Heart Rate',
      'hrv' => 'HRV',
      'spo2' => 'SpO2',
      'sleep' => 'Sleep',
      'stress' => 'Stress',
      'blood-pressure' => 'Blood Pressure',
      'recovery' => 'Stability',
      'cardio-load' => 'Cardio Load',
      _ => metric,
    };

IconData _metricIcon(String metric) => switch (metric) {
      'heart-rate' => Icons.favorite,
      'hrv' => Icons.show_chart,
      'spo2' => Icons.air,
      'sleep' => Icons.nightlight_round,
      'stress' => Icons.spa,
      'blood-pressure' => Icons.monitor_heart_outlined,
      'recovery' => Icons.shield_outlined,
      'cardio-load' => Icons.favorite_border,
      _ => Icons.bar_chart,
    };

Color _metricColor(String metric) => switch (metric) {
      'heart-rate' => AppColors.heartRate,
      'hrv' => AppColors.accent,
      'spo2' => AppColors.spo2,
      'sleep' => AppColors.sleep,
      'stress' => AppColors.warning,
      'blood-pressure' => AppColors.bloodPressure,
      'recovery' => AppColors.recovery,
      'cardio-load' => AppColors.heartRate,
      _ => AppColors.primary,
    };

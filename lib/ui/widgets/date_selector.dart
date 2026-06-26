import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';

/// Left-arrow / centered-label / right-arrow date selector. The label
/// shape depends on the current [Period]:
///
/// * `day`   → `YYYY-MM-DD` for the anchor
/// * `week`  → `MM/DD ~ MM/DD` for Monday–Sunday surrounding the anchor
/// * `month` → `YYYY-MM` for the anchor's month
///
/// The right arrow is disabled when the anchor is at or past today —
/// future days have no data and disabling makes that obvious.
class DateSelector extends StatelessWidget {
  const DateSelector({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPrev,
    required this.onNext,
    DateTime? today,
  }) : _todayOverride = today;

  final Period period;
  final DateTime anchor;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final DateTime? _todayOverride;

  DateTime _today() {
    if (_todayOverride != null) return _todayOverride;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    // For 3M the anchor is the END month — disable next when anchor month
    // is the current month (no future data).
    final today = _today();
    final canGoNext = period == Period.threeMonths
        ? anchor.isBefore(DateTime(today.year, today.month, 1))
        : anchor.isBefore(today);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
        ),
        Text(
          _formatLabel(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: Icon(
            Icons.chevron_right,
            color: canGoNext ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  String _formatLabel() {
    switch (period) {
      case Period.day:
        return ymd(anchor);
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${md(monday)} ~ ${md(sunday)}';
      case Period.month:
        return '${anchor.year}-${pad(anchor.month)}';
      case Period.threeMonths:
        // Show the start month of the 3-month window.
        final start = DateTime(anchor.year, anchor.month - 2, 1);
        return '${start.year}-${pad(start.month)} ~ ${anchor.year}-${pad(anchor.month)}';
    }
  }
}

// ─── Tiny date-format helpers shared with the chart/axis widgets ───────────

String pad(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';
String md(DateTime d) => '${pad(d.month)}/${pad(d.day)}';
String hm(DateTime d) => '${pad(d.hour)}:${pad(d.minute)}';

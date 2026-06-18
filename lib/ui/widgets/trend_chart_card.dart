import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// A single time-stamped sample to plot on a [TrendChartCard].
class TrendPoint {
  const TrendPoint({required this.at, required this.value});
  final DateTime at;
  final double value;
}

/// Y-axis style for a [TrendChartCard]. `auto` lets the chart compute
/// min/max from the data with a 10% padding; pass explicit bounds for
/// metrics with well-known reference ranges (SpO2 95-100, HR 40-180).
class TrendAxis {
  const TrendAxis.auto()
      : min = null,
        max = null,
        referenceMin = null,
        referenceMax = null;

  const TrendAxis.bounded({
    required double this.min,
    required double this.max,
    this.referenceMin,
    this.referenceMax,
  });

  final double? min;
  final double? max;

  /// Optional "good" band — rendered as a faint horizontal strip so the
  /// user sees at a glance whether their values are in/out of range.
  final double? referenceMin;
  final double? referenceMax;
}

/// Reusable line-trend card used by HR / SpO2 / Recovery / Activity
/// detail screens. Renders an optional title, the line + optional dot
/// markers, gridlines, and lo/hi axis labels.
///
/// Pass an empty list to render a polite "no data" centered message at
/// the same fixed height — callers don't need to branch on data state.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    super.key,
    required this.points,
    required this.color,
    this.title,
    this.subtitle,
    this.axis = const TrendAxis.auto(),
    this.height = 160,
    this.bottomLabels = const [],
    this.fillUnder = true,
    this.showDots = false,
  });

  final List<TrendPoint> points;
  final Color color;
  final String? title;
  final String? subtitle;
  final TrendAxis axis;
  final double height;

  /// Optional labels rendered on the X axis (left → right). Pass two
  /// (start/end times) for the Day view, seven (day names) for Week,
  /// etc. Empty list hides the axis row.
  final List<String> bottomLabels;
  final bool fillUnder;
  final bool showDots;

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
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (title != null || subtitle != null) const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No data in this range',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                : CustomPaint(
                    painter: _TrendPainter(
                      points: points,
                      color: color,
                      axis: axis,
                      fillUnder: fillUnder,
                      showDots: showDots,
                    ),
                    size: Size.infinite,
                  ),
          ),
          if (bottomLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in bottomLabels)
                  Text(
                    l,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.color,
    required this.axis,
    required this.fillUnder,
    required this.showDots,
  });

  final List<TrendPoint> points;
  final Color color;
  final TrendAxis axis;
  final bool fillUnder;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // ── compute Y bounds ──────────────────────────────────────────────
    double minY;
    double maxY;
    if (axis.min != null && axis.max != null) {
      minY = axis.min!;
      maxY = axis.max!;
    } else {
      final values = points.map((p) => p.value);
      minY = values.reduce((a, b) => a < b ? a : b);
      maxY = values.reduce((a, b) => a > b ? a : b);
      final pad = (maxY - minY) * 0.1;
      // Guard against flat data (min == max) — give the line some room.
      final flat = pad == 0;
      minY -= flat ? 1 : pad;
      maxY += flat ? 1 : pad;
    }
    if (maxY - minY <= 0) maxY = minY + 1;

    // ── compute X bounds (time) ──────────────────────────────────────
    final minX = points.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.at.millisecondsSinceEpoch.toDouble();
    final spanX = (maxX - minX) <= 0 ? 1 : (maxX - minX);

    Offset toOffset(TrendPoint p) {
      final x =
          ((p.at.millisecondsSinceEpoch - minX) / spanX) * size.width;
      final y = size.height -
          ((p.value - minY) / (maxY - minY)) * size.height;
      return Offset(x, y);
    }

    // ── reference band (faint strip in the "ok" range) ───────────────
    if (axis.referenceMin != null && axis.referenceMax != null) {
      final top = size.height -
          ((axis.referenceMax! - minY) / (maxY - minY)) * size.height;
      final bottom = size.height -
          ((axis.referenceMin! - minY) / (maxY - minY)) * size.height;
      final rect = Rect.fromLTRB(0, top, size.width, bottom);
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: 0.08),
      );
    }

    // ── gridlines (4 horizontal) ─────────────────────────────────────
    final gridPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── fill under line ───────────────────────────────────────────────
    final offsets = points.map(toOffset).toList(growable: false);
    if (fillUnder && offsets.length >= 2) {
      final path = Path()..moveTo(offsets.first.dx, size.height);
      for (final o in offsets) {
        path.lineTo(o.dx, o.dy);
      }
      path.lineTo(offsets.last.dx, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    // ── line ─────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (offsets.length == 1) {
      // Single point — render as a small dot only.
      canvas.drawCircle(offsets.first, 3, Paint()..color = color);
    } else {
      final linePath = Path()
        ..moveTo(offsets.first.dx, offsets.first.dy);
      for (var i = 1; i < offsets.length; i++) {
        linePath.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // ── dot markers (optional) ───────────────────────────────────────
    if (showDots) {
      final dotPaint = Paint()..color = color;
      for (final o in offsets) {
        canvas.drawCircle(o, 2.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points.length != points.length ||
      old.color != color ||
      old.fillUnder != fillUnder ||
      old.showDots != showDots;
}

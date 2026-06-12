import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// QWatch-style metric card. Renders:
///   • icon + title (+ optional date subtitle)
///   • optional sparkline chart in the middle (last N samples)
///   • value + unit at the bottom
///
/// `sparkline` accepts a non-empty list of doubles. If null/empty the
/// chart slot collapses and the card falls back to the old icon-only
/// look (still useful for metrics with no time series yet).
class HealthMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLocked;
  final String? lockedMessage;
  final String? date;
  final List<double>? sparkline;

  const HealthMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLocked = false,
    this.lockedMessage,
    this.date,
    this.sparkline,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? AppColors.divider
                : color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: isLocked ? _buildLocked(context) : _buildActive(context),
      ),
    );
  }

  Widget _buildActive(BuildContext context) {
    final spark = sparkline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (date != null) ...[
          const SizedBox(height: 2),
          Text(
            date!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
        if (spark != null && spark.isNotEmpty) ...[
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(samples: spark, color: color),
            ),
          ),
          const SizedBox(height: 4),
        ] else
          const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(color: color),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const Spacer(),
        Icon(Icons.lock_outline, color: AppColors.textTertiary, size: 24),
        const SizedBox(height: 4),
        Text(
          lockedMessage ?? 'Coming soon',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.samples, required this.color});
  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    if (samples.length == 1) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        p,
      );
      return;
    }

    final minV = samples.reduce((a, b) => a < b ? a : b);
    final maxV = samples.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final dx = size.width / (samples.length - 1);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = dx * i;
      final y = size.height - ((samples[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.samples != samples || old.color != color;
}

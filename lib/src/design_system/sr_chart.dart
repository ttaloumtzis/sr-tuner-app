import 'package:flutter/material.dart';

import '../classic_theme.dart';

class SrSparkChart extends StatelessWidget {
  const SrSparkChart({
    required this.points,
    this.height = 60,
    this.color,
    super.key,
  });

  final List<double> points;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final chartColor = color ?? tokens.accent;
    
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
      );
    }

    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    final normalizedPoints = range == 0 
        ? List.filled(points.length, 0.5)
        : points.map((p) => (p - min) / range).toList();

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparkChartPainter(
          points: normalizedPoints,
          color: chartColor,
          radius: tokens.radius,
        ),
      ),
    );
  }
}

class _SparkChartPainter extends CustomPainter {
  const _SparkChartPainter({
    required this.points,
    required this.color,
    required this.radius,
  });

  final List<double> points;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);
    
    // Start the first point
    path.moveTo(0, size.height * (1 - points[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - points[0]));

    // Draw through all points
    for (int i = 1; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - points[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Complete the fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

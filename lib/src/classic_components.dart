import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'classic_theme.dart';

SrTokens srTokens(BuildContext context) =>
    Theme.of(context).extension<SrTokens>() ?? SrTokens.dark;

class SrSection extends StatelessWidget {
  const SrSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(color: tokens.muted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: tokens.compactGap),
            child,
          ],
        ),
      ),
    );
  }
}

class SrBanner extends StatelessWidget {
  const SrBanner({
    required this.message,
    this.title,
    this.severity = 'info',
    this.icon,
    super.key,
  });

  final String? title;
  final String message;
  final String severity;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final color = switch (severity) {
      'success' => tokens.success,
      'warning' => tokens.warning,
      'error' => tokens.danger,
      _ => tokens.accent,
    };
    return Container(
      padding: EdgeInsets.all(tokens.compactGap),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                Text(message, style: TextStyle(color: tokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SrChip extends StatelessWidget {
  const SrChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.severity = 'info',
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final String severity;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final color = switch (severity) {
      'success' => tokens.success,
      'warning' => tokens.warning,
      'error' => tokens.danger,
      _ => selected ? tokens.accent : tokens.border,
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.14) : tokens.panel,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class SrMetricCard extends StatelessWidget {
  const SrMetricCard({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: EdgeInsets.all(tokens.compactGap),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tokens.accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          if (caption != null)
            Text(
              caption!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted),
            ),
        ],
      ),
    );
  }
}

class SrKeyboardHint extends StatelessWidget {
  const SrKeyboardHint(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

enum SrProgressKind { solid, striped, indeterminate }

class SrProgressBar extends StatefulWidget {
  const SrProgressBar({
    this.value,
    this.kind = SrProgressKind.solid,
    super.key,
  });

  final double? value;
  final SrProgressKind kind;

  @override
  State<SrProgressBar> createState() => _SrProgressBarState();
}

class _SrProgressBarState extends State<SrProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return SizedBox(
      height: 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ProgressPainter(
              value: widget.value?.clamp(0, 1),
              kind: widget.kind,
              phase: _controller.value,
              background: tokens.border.withValues(alpha: 0.45),
              foreground: tokens.accent,
            ),
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.value,
    required this.kind,
    required this.phase,
    required this.background,
    required this.foreground,
  });

  final double? value;
  final SrProgressKind kind;
  final double phase;
  final Color background;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final bg = Paint()..color = background;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, radius), bg);
    final fraction = kind == SrProgressKind.indeterminate
        ? 0.32
        : (value ?? 0).clamp(0, 1);
    final start = kind == SrProgressKind.indeterminate
        ? (size.width + size.width * fraction) * phase - size.width * fraction
        : 0.0;
    final rect = Rect.fromLTWH(start, 0, size.width * fraction, size.height);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    canvas.drawRect(rect, Paint()..color = foreground);
    if (kind == SrProgressKind.striped) {
      final stripePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 4;
      for (var x = -size.height + phase * 18; x < rect.right; x += 14) {
        canvas.drawLine(
          Offset(rect.left + x, size.height),
          Offset(rect.left + x + size.height, 0),
          stripePaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.kind != kind ||
      oldDelegate.phase != phase;
}

class SrEmptyState extends StatelessWidget {
  const SrEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: tokens.muted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.muted),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SrImagePlaceholder extends StatelessWidget {
  const SrImagePlaceholder({
    required this.label,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final String label;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: tokens.border),
        child: Center(
          child: Text(label, style: TextStyle(color: tokens.muted)),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()..addRect(Offset.zero & size);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SrSparkline extends StatelessWidget {
  const SrSparkline({required this.values, this.height = 64, super.key});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: tokens.accent),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    if (values.length < 2) {
      final text = TextPainter(
        text: TextSpan(
          text: 'No metric data',
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      text.paint(
        canvas,
        Offset(0, math.max(0, (size.height - text.height) / 2)),
      );
      return;
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 0.000001
        ? 1.0
        : maxValue - minValue;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * (index / (values.length - 1));
      final y = size.height - ((values[index] - minValue) / span * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class SrStepIndicator extends StatelessWidget {
  const SrStepIndicator({
    required this.steps,
    required this.currentIndex,
    super.key,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < steps.length; index++)
          SrChip(
            label: '${index + 1}. ${steps[index]}',
            selected: index == currentIndex,
            severity: index < currentIndex ? 'success' : 'info',
          ),
      ],
    );
  }
}

class SrCompareViewer extends StatelessWidget {
  const SrCompareViewer({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Row(
      children: [
        Expanded(child: SrImagePlaceholder(label: 'Before')),
        Container(width: 1, height: 120, color: tokens.border),
        Expanded(child: SrImagePlaceholder(label: 'After')),
      ],
    );
  }
}

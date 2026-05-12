import 'package:flutter/material.dart';

import '../classic_theme.dart';

class SrChip extends StatelessWidget {
  const SrChip({
    required this.label,
    this.icon,
    this.kind = SrChipKind.default_,
    this.size = SrChipSize.sm,
    super.key,
  });

  final String label;
  final IconData? icon;
  final SrChipKind kind;
  final SrChipSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final color = _getColor(tokens);
    final backgroundColor = color.withValues(alpha: 0.18);
    final foregroundColor = color;
    final fontSize = size == SrChipSize.sm ? 11.0 : 13.0;
    final padding = size == SrChipSize.sm 
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: foregroundColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(SrTokens tokens) {
    switch (kind) {
      case SrChipKind.ok:
        return tokens.success;
      case SrChipKind.warn:
        return tokens.warning;
      case SrChipKind.danger:
        return tokens.danger;
      case SrChipKind.accent:
        return tokens.accent;
      case SrChipKind.default_:
        return tokens.muted;
    }
  }
}

enum SrChipKind { default_, ok, warn, danger, accent }
enum SrChipSize { sm, md }

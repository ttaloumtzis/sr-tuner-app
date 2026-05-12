import 'package:flutter/material.dart';

import '../classic_theme.dart';

class SrButton extends StatelessWidget {
  const SrButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.style = SrButtonStyle.primary,
    this.size = SrButtonSize.md,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SrButtonStyle style;
  final SrButtonSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    Widget child;
    ButtonStyle buttonStyle;

    switch (style) {
      case SrButtonStyle.primary:
        buttonStyle = FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        );
        break;
      case SrButtonStyle.ghost:
        buttonStyle = OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: tokens.muted,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        );
        break;
      case SrButtonStyle.danger:
        buttonStyle = OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: tokens.danger,
          side: BorderSide(color: tokens.danger),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        );
        break;
    }

    if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    if (size == SrButtonSize.sm) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: FilledButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        ),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: child,
    );
  }

  double _getIconSize() {
    return size == SrButtonSize.sm ? 16.0 : 18.0;
  }
}

enum SrButtonStyle { primary, ghost, danger }
enum SrButtonSize { sm, md }

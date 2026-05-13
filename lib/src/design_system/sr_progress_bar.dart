import 'package:flutter/material.dart';

import '../classic_theme.dart';

enum SrProgressType { solid, striped, indeterminate }

class SrProgressBar extends StatelessWidget {
  const SrProgressBar({
    required this.progress,
    this.type = SrProgressType.solid,
    this.height = 4,
    super.key,
  });

  final double progress; // 0.0 to 1.0
  final SrProgressType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;

    if (type == SrProgressType.indeterminate) {
      return SizedBox(
        height: height,
        child: LinearProgressIndicator(
          backgroundColor: tokens.border,
          valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: tokens.border,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

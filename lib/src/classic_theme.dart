import 'package:flutter/material.dart';

@immutable
class SrTokens extends ThemeExtension<SrTokens> {
  const SrTokens({
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.muted,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.radius,
    required this.gap,
    required this.compactGap,
  });

  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color muted;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final double radius;
  final double gap;
  final double compactGap;

  static const light = SrTokens(
    panel: Color(0xfff7f9fb),
    panelAlt: Color(0xffffffff),
    border: Color(0xffd7dee7),
    muted: Color(0xff66717f),
    accent: Color(0xff256f55),
    success: Color(0xff27835f),
    warning: Color(0xffa86612),
    danger: Color(0xffb33b3b),
    radius: 4,
    gap: 16,
    compactGap: 10,
  );

  static const dark = SrTokens(
    panel: Color(0xff151a1f),
    panelAlt: Color(0xff1d232a),
    border: Color(0xff303943),
    muted: Color(0xff9aa6b2),
    accent: Color(0xff58c48a),
    success: Color(0xff5cc992),
    warning: Color(0xffffc857),
    danger: Color(0xffff6b6b),
    radius: 4,
    gap: 16,
    compactGap: 10,
  );

  @override
  SrTokens copyWith({
    Color? panel,
    Color? panelAlt,
    Color? border,
    Color? muted,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    double? radius,
    double? gap,
    double? compactGap,
  }) {
    return SrTokens(
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      radius: radius ?? this.radius,
      gap: gap ?? this.gap,
      compactGap: compactGap ?? this.compactGap,
    );
  }

  @override
  SrTokens lerp(ThemeExtension<SrTokens>? other, double t) {
    if (other is! SrTokens) {
      return this;
    }
    return SrTokens(
      panel: Color.lerp(panel, other.panel, t)!,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      radius: lerpDouble(radius, other.radius, t),
      gap: lerpDouble(gap, other.gap, t),
      compactGap: lerpDouble(compactGap, other.compactGap, t),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

class ClassicTheme {
  static const fontFamily = 'IBM Plex Sans';
  static const fallbackFonts = ['Roboto', 'Noto Sans', 'Arial'];

  static ThemeData light() => _theme(Brightness.light, SrTokens.light);

  static ThemeData dark() => _theme(Brightness.dark, SrTokens.dark);

  static ThemeData _theme(Brightness brightness, SrTokens tokens) {
    final scheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: tokens.accent,
      surface: tokens.panel,
    );
    final textTheme =
        Typography.material2021(
          platform: TargetPlatform.linux,
          colorScheme: scheme,
        ).englishLike.apply(
          fontFamily: fontFamily,
          fontFamilyFallback: fallbackFonts,
        );
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xff101418)
          : const Color(0xffedf2f7),
      textTheme: textTheme,
      extensions: [tokens],
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: tokens.panelAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.panelAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: tokens.border,
        labelColor: tokens.accent,
        unselectedLabelColor: tokens.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
          side: BorderSide(color: tokens.border),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
      ),
      visualDensity: VisualDensity.compact,
      useMaterial3: true,
    );
  }
}

import 'package:flutter/material.dart';

@immutable
class LiquidGlassColors extends ThemeExtension<LiquidGlassColors> {
  const LiquidGlassColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.backgroundGlow,
    required this.glassTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.primaryText,
    required this.secondaryText,
    required this.shadow,
    required this.success,
    required this.warning,
    required this.danger,
    required this.warningSurface,
    required this.dangerSurface,
  });

  static const deepNavy = Color(0xFF071426);
  static const coolBlue = Color(0xFF176BFF);
  static const electricBlue = Color(0xFF2878FF);
  static const cyan = Color(0xFF31C9ED);
  static const softTeal = Color(0xFF38C8B0);
  static const neutralGrey = Color(0xFF667589);
  static const amber = Color(0xFFF4B83E);
  static const orange = Color(0xFFF17C45);
  static const red = Color(0xFFE84B55);

  static const vehicles = electricBlue;
  static const plumbing = Color(0xFF23BED3);
  static const electrical = amber;
  static const appliances = Color(0xFF8B6EF3);
  static const computers = cyan;
  static const bicycles = Color(0xFF4EBE78);
  static const property = orange;
  static const industrial = Color(0xFF5685A6);

  static const light = LiquidGlassColors(
    backgroundTop: Color(0xFFF5FAFF),
    backgroundBottom: Color(0xFFE7F0F9),
    backgroundGlow: Color(0xFFBDEFFF),
    glassTint: Color(0xFFF7FBFF),
    glassBorder: Color(0xFF96B2CC),
    glassHighlight: Colors.white,
    primaryText: Color(0xFF0A1B31),
    secondaryText: Color(0xFF52657A),
    shadow: Color(0xFF183B5D),
    success: Color(0xFF117E68),
    warning: Color(0xFF9A6200),
    danger: Color(0xFFB42332),
    warningSurface: Color(0xFFFFE8B5),
    dangerSurface: Color(0xFFFFD9DD),
  );

  static const dark = LiquidGlassColors(
    backgroundTop: Color(0xFF06111F),
    backgroundBottom: Color(0xFF0A1C30),
    backgroundGlow: Color(0xFF0E6B87),
    glassTint: Color(0xFF152B42),
    glassBorder: Color(0xFF6F8EAA),
    glassHighlight: Color(0xFFD9F3FF),
    primaryText: Color(0xFFF4FAFF),
    secondaryText: Color(0xFFAFC0D1),
    shadow: Colors.black,
    success: Color(0xFF67D8BE),
    warning: Color(0xFFFFCC70),
    danger: Color(0xFFFF8992),
    warningSurface: Color(0xFF473711),
    dangerSurface: Color(0xFF4C2028),
  );

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color backgroundGlow;
  final Color glassTint;
  final Color glassBorder;
  final Color glassHighlight;
  final Color primaryText;
  final Color secondaryText;
  final Color shadow;
  final Color success;
  final Color warning;
  final Color danger;
  final Color warningSurface;
  final Color dangerSurface;

  @override
  LiquidGlassColors copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? backgroundGlow,
    Color? glassTint,
    Color? glassBorder,
    Color? glassHighlight,
    Color? primaryText,
    Color? secondaryText,
    Color? shadow,
    Color? success,
    Color? warning,
    Color? danger,
    Color? warningSurface,
    Color? dangerSurface,
  }) {
    return LiquidGlassColors(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      shadow: shadow ?? this.shadow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      warningSurface: warningSurface ?? this.warningSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
    );
  }

  @override
  LiquidGlassColors lerp(covariant LiquidGlassColors? other, double t) {
    if (other == null) {
      return this;
    }
    return LiquidGlassColors(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
    );
  }
}

extension LiquidGlassColorContext on BuildContext {
  LiquidGlassColors get glassColors {
    return Theme.of(this).extension<LiquidGlassColors>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? LiquidGlassColors.dark
            : LiquidGlassColors.light);
  }
}

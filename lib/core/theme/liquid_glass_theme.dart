import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/theme/liquid_glass_typography.dart';
import 'package:flutter/material.dart';

abstract final class LiquidGlassTheme {
  static ThemeData get light {
    return _build(
      brightness: Brightness.light,
      colors: LiquidGlassColors.light,
      tokens: LiquidGlassTokens.light,
    );
  }

  static ThemeData get dark {
    return _build(
      brightness: Brightness.dark,
      colors: LiquidGlassColors.dark,
      tokens: LiquidGlassTokens.dark,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required LiquidGlassColors colors,
    required LiquidGlassTokens tokens,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: LiquidGlassColors.coolBlue,
          brightness: brightness,
        ).copyWith(
          primary: brightness == Brightness.dark
              ? LiquidGlassColors.cyan
              : LiquidGlassColors.coolBlue,
          secondary: LiquidGlassColors.softTeal,
          surface: colors.glassTint,
          onSurface: colors.primaryText,
          error: colors.danger,
          onError: brightness == Brightness.dark ? Colors.black : Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: colors.backgroundBottom,
      textTheme: LiquidGlassTypography.textTheme(
        brightness,
      ).apply(bodyColor: colors.primaryText, displayColor: colors.primaryText),
      dividerColor: colors.glassBorder.withValues(alpha: tokens.borderOpacity),
      focusColor: colorScheme.primary.withValues(alpha: 0.18),
      highlightColor: colorScheme.primary.withValues(alpha: 0.08),
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      iconTheme: IconThemeData(color: colors.primaryText),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        labelStyle: TextStyle(color: colors.secondaryText),
        errorStyle: TextStyle(color: colors.danger),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(
          color: colors.glassBorder.withValues(alpha: tokens.borderOpacity),
        ),
        shape: const StadiumBorder(),
        backgroundColor: colors.glassTint.withValues(alpha: 0.45),
        selectedColor: colorScheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: colors.primaryText),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF18324B)
            : LiquidGlassColors.deepNavy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      extensions: <ThemeExtension<dynamic>>[colors, tokens],
    );
  }
}

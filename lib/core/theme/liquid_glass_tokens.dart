import 'package:flutter/material.dart';

@immutable
class LiquidGlassTokens extends ThemeExtension<LiquidGlassTokens> {
  const LiquidGlassTokens({
    required this.blurSigma,
    required this.surfaceOpacity,
    required this.borderOpacity,
    required this.highlightOpacity,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.cardRadius,
    required this.controlRadius,
    required this.dialogRadius,
    required this.navigationRadius,
    required this.navigationHeight,
    required this.contentPadding,
  });

  static const light = LiquidGlassTokens(
    blurSigma: 20,
    surfaceOpacity: 0.66,
    borderOpacity: 0.25,
    highlightOpacity: 0.72,
    shadowOpacity: 0.12,
    shadowBlur: 28,
    shadowOffset: Offset(0, 12),
    cardRadius: 26,
    controlRadius: 18,
    dialogRadius: 30,
    navigationRadius: 30,
    navigationHeight: 72,
    contentPadding: 20,
  );

  static const dark = LiquidGlassTokens(
    blurSigma: 18,
    surfaceOpacity: 0.46,
    borderOpacity: 0.28,
    highlightOpacity: 0.28,
    shadowOpacity: 0.32,
    shadowBlur: 30,
    shadowOffset: Offset(0, 14),
    cardRadius: 26,
    controlRadius: 18,
    dialogRadius: 30,
    navigationRadius: 30,
    navigationHeight: 72,
    contentPadding: 20,
  );

  final double blurSigma;
  final double surfaceOpacity;
  final double borderOpacity;
  final double highlightOpacity;
  final double shadowOpacity;
  final double shadowBlur;
  final Offset shadowOffset;
  final double cardRadius;
  final double controlRadius;
  final double dialogRadius;
  final double navigationRadius;
  final double navigationHeight;
  final double contentPadding;

  @override
  LiquidGlassTokens copyWith({
    double? blurSigma,
    double? surfaceOpacity,
    double? borderOpacity,
    double? highlightOpacity,
    double? shadowOpacity,
    double? shadowBlur,
    Offset? shadowOffset,
    double? cardRadius,
    double? controlRadius,
    double? dialogRadius,
    double? navigationRadius,
    double? navigationHeight,
    double? contentPadding,
  }) {
    return LiquidGlassTokens(
      blurSigma: blurSigma ?? this.blurSigma,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      highlightOpacity: highlightOpacity ?? this.highlightOpacity,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      navigationRadius: navigationRadius ?? this.navigationRadius,
      navigationHeight: navigationHeight ?? this.navigationHeight,
      contentPadding: contentPadding ?? this.contentPadding,
    );
  }

  @override
  LiquidGlassTokens lerp(covariant LiquidGlassTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return LiquidGlassTokens(
      blurSigma: _lerpDouble(blurSigma, other.blurSigma, t),
      surfaceOpacity: _lerpDouble(surfaceOpacity, other.surfaceOpacity, t),
      borderOpacity: _lerpDouble(borderOpacity, other.borderOpacity, t),
      highlightOpacity: _lerpDouble(
        highlightOpacity,
        other.highlightOpacity,
        t,
      ),
      shadowOpacity: _lerpDouble(shadowOpacity, other.shadowOpacity, t),
      shadowBlur: _lerpDouble(shadowBlur, other.shadowBlur, t),
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      controlRadius: _lerpDouble(controlRadius, other.controlRadius, t),
      dialogRadius: _lerpDouble(dialogRadius, other.dialogRadius, t),
      navigationRadius: _lerpDouble(
        navigationRadius,
        other.navigationRadius,
        t,
      ),
      navigationHeight: _lerpDouble(
        navigationHeight,
        other.navigationHeight,
        t,
      ),
      contentPadding: _lerpDouble(contentPadding, other.contentPadding, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

extension LiquidGlassTokenContext on BuildContext {
  LiquidGlassTokens get glassTokens {
    return Theme.of(this).extension<LiquidGlassTokens>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? LiquidGlassTokens.dark
            : LiquidGlassTokens.light);
  }
}

import 'dart:ui';

import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiquidGlassContainer extends ConsumerWidget {
  const LiquidGlassContainer({
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.radius,
    this.tint,
    this.surfaceOpacity,
    this.borderColor,
    this.enableBlur = true,
    this.showShadow = true,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double? radius;
  final Color? tint;
  final double? surfaceOpacity;
  final Color? borderColor;
  final bool enableBlur;
  final bool showShadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.glassColors;
    final tokens = context.glassTokens;
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final effects = ref.watch(accessibilityEffectsControllerProvider);
    final effectiveMode = effects.effectiveMode(mediaQuery);
    final blurSigma = enableBlur ? effects.blurSigma(tokens, mediaQuery) : 0.0;
    final opacity =
        surfaceOpacity ?? effects.surfaceOpacity(tokens, mediaQuery).toDouble();
    final resolvedTint = tint ?? colors.glassTint;
    final resolvedRadius = BorderRadius.circular(radius ?? tokens.cardRadius);
    final borderOpacity = effectiveMode == EffectMode.minimal
        ? 0.48
        : tokens.borderOpacity;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        border: Border.all(
          color: (borderColor ?? colors.glassBorder).withValues(
            alpha: borderOpacity,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            resolvedTint.withValues(
              alpha: (opacity + tokens.highlightOpacity * 0.08)
                  .clamp(0, 1)
                  .toDouble(),
            ),
            resolvedTint.withValues(alpha: opacity),
          ],
        ),
      ),
      child: child,
    );

    if (blurSigma > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    content = ClipRRect(borderRadius: resolvedRadius, child: content);

    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: tokens.shadowOpacity),
                  blurRadius: tokens.shadowBlur,
                  offset: tokens.shadowOffset,
                ),
              ]
            : null,
      ),
      child: content,
    );

    return RepaintBoundary(
      child: semanticLabel == null
          ? content
          : Semantics(container: true, label: semanticLabel, child: content),
    );
  }
}

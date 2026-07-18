import 'dart:async';
import 'dart:math' as math;

import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FluidBackground extends ConsumerStatefulWidget {
  const FluidBackground({required this.child, this.accent, super.key});

  final Widget child;
  final Color? accent;

  @override
  ConsumerState<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends ConsumerState<FluidBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.backgroundLoop,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final effects = ref.watch(accessibilityEffectsControllerProvider);
    final shouldAnimate =
        effects.motionAllowed(mediaQuery) &&
        TickerMode.valuesOf(context).enabled;

    if (shouldAnimate && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _FluidBackgroundPainter(
              progress: _controller,
              top: colors.backgroundTop,
              bottom: colors.backgroundBottom,
              glow: colors.backgroundGlow,
              accent: widget.accent ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _FluidBackgroundPainter extends CustomPainter {
  _FluidBackgroundPainter({
    required Animation<double> progress,
    required this.top,
    required this.bottom,
    required this.glow,
    required this.accent,
  }) : _progress = progress,
       super(repaint: progress);

  final Animation<double> _progress;
  final Color top;
  final Color bottom;
  final Color glow;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ).createShader(bounds);
    canvas.drawRect(bounds, background);

    final phase = _progress.value * math.pi * 2;
    _drawGlow(
      canvas,
      Offset(
        size.width * (0.18 + math.sin(phase) * 0.04),
        size.height * (0.22 + math.cos(phase) * 0.03),
      ),
      size.shortestSide * 0.42,
      glow.withValues(alpha: 0.32),
    );
    _drawGlow(
      canvas,
      Offset(
        size.width * (0.82 + math.cos(phase * 0.8) * 0.04),
        size.height * (0.55 + math.sin(phase * 0.7) * 0.05),
      ),
      size.shortestSide * 0.38,
      accent.withValues(alpha: 0.18),
    );
    _drawGlow(
      canvas,
      Offset(size.width * 0.48, size.height * 0.94),
      size.shortestSide * 0.46,
      LiquidGlassColors.softTeal.withValues(alpha: 0.13),
    );
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidBackgroundPainter oldDelegate) {
    return oldDelegate.top != top ||
        oldDelegate.bottom != bottom ||
        oldDelegate.glow != glow ||
        oldDelegate.accent != accent;
  }
}

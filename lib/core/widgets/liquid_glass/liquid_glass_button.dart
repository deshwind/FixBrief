import 'dart:async';

import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LiquidGlassButtonLevel { primary, secondary, plain }

enum LiquidGlassButtonStatus { idle, success, error }

class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.level = LiquidGlassButtonLevel.primary,
    this.status = LiquidGlassButtonStatus.idle,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LiquidGlassButtonLevel level;
  final LiquidGlassButtonStatus status;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  var _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _activate() {
    if (!_enabled) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final colorScheme = Theme.of(context).colorScheme;
    final baseForeground = switch (widget.level) {
      LiquidGlassButtonLevel.primary => Colors.white,
      LiquidGlassButtonLevel.secondary ||
      LiquidGlassButtonLevel.plain => colors.primaryText,
    };
    final foreground = widget.onPressed == null
        ? baseForeground.withValues(alpha: 0.52)
        : baseForeground;
    final tint = switch (widget.status) {
      LiquidGlassButtonStatus.success => colors.success,
      LiquidGlassButtonStatus.error => colors.danger,
      LiquidGlassButtonStatus.idle => switch (widget.level) {
        LiquidGlassButtonLevel.primary => colorScheme.primary,
        LiquidGlassButtonLevel.secondary => colors.glassTint,
        LiquidGlassButtonLevel.plain => Colors.transparent,
      },
    };

    final content = AnimatedSwitcher(
      duration: MotionTokens.smallChange,
      child: widget.isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: foreground,
                semanticsLabel: '${widget.label} in progress',
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(widget.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
    );

    Widget button;
    if (widget.level == LiquidGlassButtonLevel.plain) {
      button = TextButton(
        onPressed: _enabled ? _activate : null,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: content,
      );
    } else {
      button = LiquidGlassContainer(
        height: 54,
        radius: 18,
        tint: tint,
        surfaceOpacity: widget.level == LiquidGlassButtonLevel.primary
            ? widget.onPressed == null
                  ? 0.58
                  : 0.9
            : null,
        showShadow: widget.level == LiquidGlassButtonLevel.primary,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _enabled ? _activate : null,
            onHighlightChanged: _enabled
                ? (value) => setState(() => _pressed = value)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: DefaultTextStyle.merge(
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      child: AnimatedScale(
        duration: MotionTokens.buttonFeedback,
        curve: MotionTokens.standardCurve,
        scale: _pressed ? 0.97 : 1,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

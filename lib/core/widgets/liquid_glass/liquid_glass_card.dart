import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    required this.child,
    this.onTap,
    this.padding,
    this.semanticLabel,
    this.tint,
    this.radius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;
  final Color? tint;
  final double? radius;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedScale(
      duration: MotionTokens.buttonFeedback,
      scale: _pressed ? 0.985 : 1,
      curve: MotionTokens.standardCurve,
      child: LiquidGlassContainer(
        padding: widget.padding,
        semanticLabel: widget.semanticLabel,
        tint: widget.tint,
        radius: widget.radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null
                ? null
                : (value) => setState(() => _pressed = value),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap == null) {
      return card;
    }
    return Semantics(button: true, label: widget.semanticLabel, child: card);
  }
}

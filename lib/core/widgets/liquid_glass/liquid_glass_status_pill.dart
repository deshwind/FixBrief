import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:flutter/material.dart';

enum LiquidGlassStatus { neutral, info, success, warning, danger }

class LiquidGlassStatusPill extends StatelessWidget {
  const LiquidGlassStatusPill({
    required this.label,
    this.status = LiquidGlassStatus.neutral,
    super.key,
  });

  final String label;
  final LiquidGlassStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final color = switch (status) {
      LiquidGlassStatus.neutral => colors.secondaryText,
      LiquidGlassStatus.info => Theme.of(context).colorScheme.primary,
      LiquidGlassStatus.success => colors.success,
      LiquidGlassStatus.warning => colors.warning,
      LiquidGlassStatus.danger => colors.danger,
    };
    final icon = switch (status) {
      LiquidGlassStatus.neutral => Icons.circle_outlined,
      LiquidGlassStatus.info => Icons.info_outline_rounded,
      LiquidGlassStatus.success => Icons.check_circle_outline_rounded,
      LiquidGlassStatus.warning => Icons.warning_amber_rounded,
      LiquidGlassStatus.danger => Icons.error_outline_rounded,
    };

    return Semantics(
      label: '$label, ${status.name} status',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

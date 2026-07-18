import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:flutter/material.dart';

class LiquidGlassChip extends StatelessWidget {
  const LiquidGlassChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onSelected,
    this.accent,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final tokens = context.glassTokens;
    final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: onSelected != null,
      label: label,
      child: AnimatedContainer(
        duration: MotionTokens.smallChange,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? resolvedAccent.withValues(alpha: 0.17)
              : colors.glassTint.withValues(alpha: 0.62),
          border: Border.all(
            color: selected
                ? resolvedAccent.withValues(alpha: 0.58)
                : colors.glassBorder.withValues(alpha: tokens.borderOpacity),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onSelected == null ? null : () => onSelected!(!selected),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: resolvedAccent),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? resolvedAccent : colors.primaryText,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class LiquidGlassProgressIndicator extends StatelessWidget {
  const LiquidGlassProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.label,
    super.key,
  }) : assert(currentStep > 0),
       assert(totalSteps > 0),
       assert(currentStep <= totalSteps);

  final int currentStep;
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label, step $currentStep of $totalSteps',
      value: '${(currentStep / totalSteps * 100).round()} percent',
      child: LiquidGlassContainer(
        radius: 18,
        showShadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: currentStep / totalSteps,
                      minHeight: 6,
                      backgroundColor: colors.glassBorder.withValues(
                        alpha: 0.18,
                      ),
                      color: colorScheme.primary,
                      semanticsLabel: label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            AnimatedSwitcher(
              duration: MotionTokens.smallChange,
              child: Text(
                '$currentStep/$totalSteps',
                key: ValueKey(currentStep),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:flutter/material.dart';

class ProvisionalWarningCard extends StatelessWidget {
  const ProvisionalWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: provisionalEstimateWarning,
      child: LiquidGlassCard(
        tint: LiquidGlassColors.amber,
        padding: const EdgeInsets.all(17),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: LiquidGlassColors.amber),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                provisionalEstimateWarning,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:flutter/material.dart';

class AuthFeedback extends StatelessWidget {
  const AuthFeedback({this.error, this.notice, super.key});

  final String? error;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final message = error ?? notice;
    if (message == null) {
      return const SizedBox.shrink();
    }
    final isError = error != null;
    final color = isError
        ? context.glassColors.danger
        : context.glassColors.success;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

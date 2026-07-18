import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthShell(
      showBack: false,
      maxWidth: 760,
      title: 'How will you use FixBrief?',
      subtitle:
          'Choose carefully. Your account type controls access and cannot be changed from the app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFeedback(error: state.errorMessage, notice: state.noticeMessage),
          if (state.errorMessage != null || state.noticeMessage != null)
            const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _RoleCard(
                  title: 'I need something repaired',
                  description:
                      'Create clear repair requests, compare provisional quotes, and manage a repair.',
                  icon: Icons.home_repair_service_rounded,
                  accent: LiquidGlassColors.coolBlue,
                  enabled: !state.isSubmitting,
                  onTap: () => unawaited(
                    ref
                        .read(authSessionControllerProvider.notifier)
                        .selectRole(UserRole.customer),
                  ),
                ),
                _RoleCard(
                  title: 'I am a repair professional',
                  description:
                      'Build a business profile, receive suitable requests, and manage quotes and jobs.',
                  icon: Icons.handyman_rounded,
                  accent: LiquidGlassColors.industrial,
                  enabled: !state.isSubmitting,
                  onTap: () => unawaited(
                    ref
                        .read(authSessionControllerProvider.notifier)
                        .selectRole(UserRole.repairer),
                  ),
                ),
              ];
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    cards.first,
                    const SizedBox(height: 14),
                    cards.last,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards.first),
                  const SizedBox(width: 14),
                  Expanded(child: cards.last),
                ],
              );
            },
          ),
          if (state.isSubmitting) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              semanticsLabel: 'Saving account type',
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'For security, the server records the role once. Support review will be required for any future change.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: LiquidGlassCard(
        semanticLabel: title,
        onTap: enabled ? onTap : null,
        tint: accent,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 38, color: accent),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 9),
            Text(description),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Choose this account',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

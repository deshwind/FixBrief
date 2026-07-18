import 'dart:async';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionControllerProvider);
    final email = state.verificationEmail ?? 'your email address';
    return AuthShell(
      title: 'Verify your email',
      subtitle: 'We sent a verification link to $email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 58),
          const SizedBox(height: 18),
          const Text(
            'Open the link on this device. FixBrief will handle the secure callback automatically.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          AuthFeedback(error: state.errorMessage, notice: state.noticeMessage),
          if (state.errorMessage != null || state.noticeMessage != null)
            const SizedBox(height: 18),
          LiquidGlassButton(
            label: 'I have verified my email',
            icon: Icons.verified_outlined,
            expand: true,
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting
                ? null
                : () => unawaited(
                    ref
                        .read(authSessionControllerProvider.notifier)
                        .checkEmailVerification(),
                  ),
          ),
          const SizedBox(height: 12),
          LiquidGlassButton(
            label: 'Resend verification email',
            level: LiquidGlassButtonLevel.secondary,
            expand: true,
            onPressed: state.isSubmitting
                ? null
                : () => unawaited(
                    ref
                        .read(authSessionControllerProvider.notifier)
                        .resendVerification(),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(AppPaths.login),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(appEnvironmentProvider).useDemoAuthentication;
    return AuthShell(
      showBack: false,
      title: 'Repairs start with a clearer brief.',
      subtitle:
          'Describe the problem, organise the evidence, and connect with a suitable repair professional.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WelcomeFeature(
            icon: Icons.auto_awesome_rounded,
            title: 'AI-assisted intake',
            description:
                'Possible causes and useful questions—not a diagnosis.',
          ),
          const SizedBox(height: 14),
          const _WelcomeFeature(
            icon: Icons.verified_user_outlined,
            title: 'Privacy-first matching',
            description:
                'Share only what a repair professional needs to quote.',
          ),
          const SizedBox(height: 14),
          const _WelcomeFeature(
            icon: Icons.handyman_outlined,
            title: 'Two purpose-built experiences',
            description: 'For customers and verified repair professionals.',
          ),
          if (demoMode) ...[const SizedBox(height: 18), const _DemoNotice()],
          const SizedBox(height: 26),
          LiquidGlassButton(
            label: 'Create an account',
            icon: Icons.person_add_alt_1_rounded,
            expand: true,
            onPressed: () => context.go(AppPaths.register),
          ),
          const SizedBox(height: 12),
          LiquidGlassButton(
            label: 'Sign in',
            icon: Icons.login_rounded,
            level: LiquidGlassButtonLevel.secondary,
            expand: true,
            onPressed: () => context.go(AppPaths.login),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Development demo: no account data leaves this device. Use any valid email and a 12-character password.',
      ),
    );
  }
}

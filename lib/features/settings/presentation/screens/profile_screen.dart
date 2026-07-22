import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/notifications/presentation/providers/notification_providers.dart';
import 'package:fixbrief/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionControllerProvider);
    final role = auth.onboarding.role ?? UserRole.customer;
    final email = auth.user?.email ?? 'Signed-in member';
    final name = _nameFromEmail(email);
    final unread = ref.watch(unreadNotificationCountProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: role == UserRole.customer ? 'Customer home' : 'Dashboard',
          onPressed: () => context.go(
            role == UserRole.customer
                ? AppPaths.customerHome
                : AppPaths.repairerDashboard,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: const [NotificationBell()],
      ),
      body: FluidBackground(
        accent: role == UserRole.customer
            ? LiquidGlassColors.coolBlue
            : LiquidGlassColors.industrial,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            LiquidGlassCard(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(email, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          role == UserRole.customer
                              ? 'Customer account'
                              : 'Repair professional account',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LiquidGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: unread == 0
                        ? 'You are all caught up'
                        : '$unread unread updates',
                    onTap: () => context.push(AppPaths.notifications),
                  ),
                  const Divider(height: 1, indent: 72),
                  _ProfileTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings and accessibility',
                    subtitle: 'Appearance, alerts, privacy, and account',
                    onTap: () => context.push(AppPaths.settings),
                  ),
                  const Divider(height: 1, indent: 72),
                  _ProfileTile(
                    icon: role == UserRole.customer
                        ? Icons.history_rounded
                        : Icons.handyman_outlined,
                    title: role == UserRole.customer
                        ? 'Repair history'
                        : 'Jobs and reviews',
                    subtitle: 'Completed work and feedback',
                    onTap: () => context.go(
                      role == UserRole.customer
                          ? AppPaths.customerJobs
                          : AppPaths.repairerJobs,
                    ),
                  ),
                  const Divider(height: 1, indent: 72),
                  _ProfileTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help and support',
                    subtitle: 'Safety, account, and repair help',
                    onTap: () => context.push(AppPaths.helpSupport),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: auth.isSubmitting
                  ? null
                  : () => unawaited(
                      ref
                          .read(authSessionControllerProvider.notifier)
                          .signOut(),
                    ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

String _nameFromEmail(String email) {
  final raw = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
  if (raw.isEmpty) {
    return 'FixBrief member';
  }
  return raw
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/presentation/controllers/settings_state.dart';
import 'package:fixbrief/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SettingsState>(settingsControllerProvider, (previous, next) {
      final message = next.errorMessage ?? next.noticeMessage;
      if (message != null &&
          message != previous?.errorMessage &&
          message != previous?.noticeMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final state = ref.watch(settingsControllerProvider);
    final settings = state.settings;
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    final controller = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              _SectionTitle('Appearance'),
              LiquidGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: AppThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) =>
                          controller.setThemeMode(selection.first),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Visual effects',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in EffectMode.values)
                          ChoiceChip(
                            label: Text(switch (mode) {
                              EffectMode.full => 'Full',
                              EffectMode.reduced => 'Reduced',
                              EffectMode.minimal => 'Minimal',
                            }),
                            selected: settings.effectMode == mode,
                            onSelected: (_) => controller.setEffectMode(mode),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _SectionTitle('Accessibility'),
              LiquidGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Reduce transparency'),
                      subtitle: const Text(
                        'Uses opaque surfaces instead of background blur.',
                      ),
                      value: settings.reduceTransparency,
                      onChanged: controller.setReduceTransparency,
                    ),
                    const Divider(height: 1, indent: 72),
                    SwitchListTile.adaptive(
                      title: const Text('Reduce motion'),
                      subtitle: const Text(
                        'Stops decorative and reveal animations.',
                      ),
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                    ),
                  ],
                ),
              ),
              _SectionTitle('Notifications'),
              _NotificationSettingsCard(
                role: role,
                preferences: settings.notifications,
                enabled: !state.isSaving,
                onChanged: controller.updateNotifications,
              ),
              _SectionTitle('Privacy and data'),
              LiquidGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Request a data export'),
                      subtitle: Text(
                        settings.latestExport == null
                            ? 'Prepare a portable copy of your FixBrief data.'
                            : 'Latest request: ${settings.latestExport!.status} · ${DateFormat('d MMM y').format(settings.latestExport!.requestedAt)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      enabled: !state.isSaving,
                      onTap: () => unawaited(controller.requestDataExport()),
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text('Blocked users'),
                      subtitle: const Text(
                        'Review and manage blocked members.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppPaths.blockedUsers),
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy policy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppPaths.privacyPolicy),
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms and conditions'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppPaths.terms),
                    ),
                  ],
                ),
              ),
              _SectionTitle('Support'),
              LiquidGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Help and support'),
                  subtitle: const Text(
                    'FAQs, safety guidance, and contact details.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppPaths.helpSupport),
                ),
              ),
              _SectionTitle('Account'),
              _AccountDeletionCard(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({
    required this.role,
    required this.preferences,
    required this.enabled,
    required this.onChanged,
  });

  final UserRole role;
  final NotificationPreferences preferences;
  final bool enabled;
  final ValueChanged<NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _PreferenceSwitch(
            title: 'Push notifications',
            subtitle: 'Prepared for device push delivery in Stage 12.',
            value: preferences.pushEnabled,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(pushEnabled: value)),
          ),
          _PreferenceSwitch(
            title: 'Email notifications',
            subtitle: 'Important account and repair updates.',
            value: preferences.emailEnabled,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(emailEnabled: value)),
          ),
          _PreferenceSwitch(
            title: 'New messages',
            value: preferences.newMessages,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(newMessages: value)),
          ),
          _PreferenceSwitch(
            title: 'Quote updates',
            value: preferences.quoteUpdates,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(quoteUpdates: value)),
          ),
          _PreferenceSwitch(
            title: 'Appointments and reminders',
            value: preferences.appointmentReminders,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(appointmentReminders: value)),
          ),
          _PreferenceSwitch(
            title: 'Job status updates',
            value: preferences.jobUpdates,
            enabled: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(jobUpdates: value)),
          ),
          if (role == UserRole.repairer)
            _PreferenceSwitch(
              title: 'New matching requests',
              value: preferences.matchingRequests,
              enabled: enabled,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(matchingRequests: value)),
            ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _AccountDeletionCard extends ConsumerWidget {
  const _AccountDeletionCard({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = state.settings.deletionRequest;
    if (request != null) {
      return LiquidGlassCard(
        tint: context.glassColors.dangerSurface,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account deletion scheduled',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Your account is scheduled for deletion on ${DateFormat('d MMMM y').format(request.scheduledFor)}. You can cancel before processing begins.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: state.isSaving
                  ? null
                  : () => unawaited(
                      ref
                          .read(settingsControllerProvider.notifier)
                          .cancelAccountDeletion(),
                    ),
              child: const Text('Cancel account deletion'),
            ),
          ],
        ),
      );
    }
    return LiquidGlassCard(
      tint: context.glassColors.dangerSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete account',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Schedules permanent deletion after a 14-day recovery period. Active disputes may delay processing.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: state.isSaving
                ? null
                : () => _confirmDeletion(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Schedule account deletion'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    var confirmation = '';
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete your FixBrief account?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This schedules deletion in 14 days. Export your data first if you need a copy. Type DELETE to continue.',
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) =>
                      setDialogState(() => confirmation = value),
                  decoration: const InputDecoration(labelText: 'Type DELETE'),
                ),
                const SizedBox(height: 10),
                TextField(
                  maxLength: 1000,
                  maxLines: 3,
                  onChanged: (value) => reason = value,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep account'),
            ),
            FilledButton(
              onPressed: confirmation == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Schedule deletion'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final success = await ref
        .read(settingsControllerProvider.notifier)
        .requestAccountDeletion(reason: reason);
    if (success && context.mounted) {
      await ref.read(authSessionControllerProvider.notifier).signOut();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

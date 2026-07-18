import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  static const _categories = [
    (
      label: 'Vehicles',
      icon: Icons.directions_car_filled_rounded,
      color: LiquidGlassColors.vehicles,
    ),
    (
      label: 'Plumbing',
      icon: Icons.plumbing_rounded,
      color: LiquidGlassColors.plumbing,
    ),
    (
      label: 'Electrical',
      icon: Icons.electrical_services_rounded,
      color: LiquidGlassColors.electrical,
    ),
    (
      label: 'Appliances',
      icon: Icons.kitchen_rounded,
      color: LiquidGlassColors.appliances,
    ),
    (
      label: 'Computers',
      icon: Icons.laptop_mac_rounded,
      color: LiquidGlassColors.computers,
    ),
    (
      label: 'Bicycles',
      icon: Icons.pedal_bike_rounded,
      color: LiquidGlassColors.bicycles,
    ),
    (
      label: 'Property',
      icon: Icons.home_repair_service_rounded,
      color: LiquidGlassColors.property,
    ),
    (
      label: 'Industrial',
      icon: Icons.precision_manufacturing_rounded,
      color: LiquidGlassColors.industrial,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(repairRequestWizardControllerProvider).draft;
    final isDemo = ref.watch(appEnvironmentProvider).useDemoAuthentication;
    final quoteRequestId = isDemo
        ? 'demo-request-vehicle'
        : draft?.status == RepairDraftStatus.submitted
        ? draft?.id
        : null;
    return Scaffold(
      extendBody: true,
      body: FluidBackground(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HomeHeader(
                                onAssessmentTap: () {
                                  if (draft?.status ==
                                      RepairDraftStatus.submitted) {
                                    context.go(
                                      AppPaths.aiAssessmentFor(draft!.id),
                                    );
                                  } else if (isDemo) {
                                    context.go(
                                      AppPaths.aiAssessmentFor('preview'),
                                    );
                                  } else {
                                    _showStageMessage(
                                      context,
                                      'Submit a repair request before starting an assessment.',
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 28),
                              const _Greeting(),
                              const SizedBox(height: 24),
                              LiquidGlassButton(
                                label: 'Start a new repair request',
                                semanticLabel: 'Start a new repair request',
                                icon: Icons.add_circle_outline_rounded,
                                expand: true,
                                onPressed: () =>
                                    _openRepairWizard(context, ref),
                              ),
                              const SizedBox(height: 32),
                              const _SectionHeader(
                                title: 'Active repair',
                                actionLabel: 'View details',
                              ),
                              const SizedBox(height: 14),
                              _ActiveRepairCard(
                                onTap: () {
                                  if (quoteRequestId != null) {
                                    context.go(
                                      AppPaths.customerQuoteComparisonFor(
                                        quoteRequestId,
                                      ),
                                    );
                                  } else {
                                    _showStageMessage(
                                      context,
                                      'Publish a repair request before comparing quotes.',
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 32),
                              const _SectionHeader(
                                title: 'What needs fixing?',
                                actionLabel: 'View all',
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 850
                                      ? 4
                                      : constraints.maxWidth >= 520
                                      ? 3
                                      : 2;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _categories.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: columns == 2
                                              ? 1.48
                                              : 1.7,
                                        ),
                                    itemBuilder: (context, index) {
                                      final category = _categories[index];
                                      return _CategoryCard(
                                        label: category.label,
                                        icon: category.icon,
                                        accent: category.color,
                                        onTap: () =>
                                            _openRepairWizard(context, ref),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              const _SafetyReminder(),
                              const SizedBox(height: 32),
                              const _SectionHeader(
                                title: 'Recent activity',
                                actionLabel: 'Repair history',
                              ),
                              const SizedBox(height: 14),
                              const _RecentActivity(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: LiquidGlassNavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (index) {
                    if (index == 1 && quoteRequestId != null) {
                      context.go(
                        AppPaths.customerQuoteComparisonFor(quoteRequestId),
                      );
                    } else if (index != 0) {
                      _showStageMessage(
                        context,
                        'This Stage 2 prototype demonstrates the customer Home destination.',
                      );
                    }
                  },
                  destinations: const [
                    LiquidGlassNavigationDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    LiquidGlassNavigationDestination(
                      icon: Icons.build_circle_outlined,
                      selectedIcon: Icons.build_circle_rounded,
                      label: 'Requests',
                    ),
                    LiquidGlassNavigationDestination(
                      icon: Icons.chat_bubble_outline_rounded,
                      selectedIcon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                    ),
                    LiquidGlassNavigationDestination(
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showStageMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _openRepairWizard(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(repairRequestWizardControllerProvider);
    if (state.draft?.status == RepairDraftStatus.submitted) {
      await ref
          .read(repairRequestWizardControllerProvider.notifier)
          .startFreshDraft();
    }
    if (context.mounted) {
      context.go(AppPaths.repairRequestCategory);
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onAssessmentTap});

  final VoidCallback onAssessmentTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _FixBriefMark(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'FixBrief',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _GlassIconAction(
          tooltip: 'Open AI assessment',
          icon: Icons.auto_awesome_rounded,
          onPressed: onAssessmentTap,
        ),
        const SizedBox(width: 8),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _FixBriefMark extends StatelessWidget {
  const _FixBriefMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FixBrief repair link symbol',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LiquidGlassColors.coolBlue, LiquidGlassColors.cyan],
          ),
        ),
        child: const Icon(Icons.link_rounded, color: Colors.white),
      ),
    );
  }
}

class _GlassIconAction extends StatelessWidget {
  const _GlassIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: LiquidGlassContainer(
        radius: 16,
        showShadow: false,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Alex',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'From strange sounds to trusted quotes.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveRepairCard extends StatelessWidget {
  const _ActiveRepairCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    return LiquidGlassCard(
      semanticLabel: 'Active vehicle repair, three quotes received',
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: LiquidGlassColors.vehicles.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: LiquidGlassColors.vehicles,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ford Focus clicking noise',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Published today · Manchester M20',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const LiquidGlassStatusPill(
                label: '3 quotes',
                status: LiquidGlassStatus.info,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimates from £140–£345',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: colors.secondaryText),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      semanticLabel: '$label repair category',
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 29),
          const SizedBox(height: 9),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _SafetyReminder extends StatelessWidget {
  const _SafetyReminder();

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    return Semantics(
      container: true,
      label:
          'Safety reminder. Stop using anything that is smoking, sparking, leaking fuel or gas, or unsafe to control.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.warningSurface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_rounded, color: colors.warning),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety comes first',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Stop using anything that is smoking, sparking, leaking fuel or gas, or unsafe to control. Contact a qualified professional.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _ActivityTile(
            icon: Icons.phone_android_rounded,
            accent: LiquidGlassColors.computers,
            title: 'Phone charging issue',
            subtitle: 'Completed · 14 June',
            trailing: '£72',
          ),
          Divider(
            height: 1,
            indent: 72,
            color: context.glassColors.glassBorder.withValues(alpha: 0.22),
          ),
          _ActivityTile(
            icon: Icons.chair_alt_rounded,
            accent: LiquidGlassColors.property,
            title: 'Dining chair frame repair',
            subtitle: 'Closed · 2 May',
            trailing: '£110',
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 42,
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.14),
        foregroundColor: accent,
        child: Icon(icon, size: 21),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(trailing, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

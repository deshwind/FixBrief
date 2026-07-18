import 'package:cached_network_image/cached_network_image.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RepairerProfileScreen extends ConsumerWidget {
  const RepairerProfileScreen({required this.repairerId, super.key});

  final String repairerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnProfile = repairerId == 'me';
    final profile = ref.watch(
      repairerMarketplaceProfileProvider(isOwnProfile ? null : repairerId),
    );
    return Scaffold(
      extendBody: isOwnProfile,
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: Stack(
          children: [
            SafeArea(
              child: profile.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading repairer profile',
                  ),
                ),
                error: (error, stackTrace) => _ProfileError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(
                    repairerMarketplaceProfileProvider(
                      isOwnProfile ? null : repairerId,
                    ),
                  ),
                ),
                data: (value) =>
                    _ProfileContent(profile: value, isOwnProfile: isOwnProfile),
              ),
            ),
            if (isOwnProfile)
              const RepairerMarketplaceNavigation(selectedIndex: 4),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required this.isOwnProfile});

  final RepairerMarketplaceProfile profile;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  isOwnProfile ? 132 : 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(isOwnProfile: isOwnProfile),
                    const SizedBox(height: 24),
                    _ProfileHero(profile: profile),
                    const SizedBox(height: 16),
                    _ProfileMetrics(profile: profile),
                    const SizedBox(height: 16),
                    _AboutCard(profile: profile),
                    const SizedBox(height: 16),
                    _SpecialisationsCard(profile: profile),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final coverage = _CoverageCard(profile: profile);
                        final availability = _AvailabilityCard(
                          profile: profile,
                        );
                        if (constraints.maxWidth < 680) {
                          return Column(
                            children: [
                              coverage,
                              const SizedBox(height: 16),
                              availability,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: coverage),
                            const SizedBox(width: 16),
                            Expanded(child: availability),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _QualificationsCard(profile: profile),
                    if (isOwnProfile) ...[
                      const SizedBox(height: 20),
                      LiquidGlassButton(
                        label: 'Edit business profile',
                        icon: Icons.edit_outlined,
                        expand: true,
                        level: LiquidGlassButtonLevel.secondary,
                        onPressed: () => _showLater(
                          context,
                          'Profile editing will use the verified onboarding workflow in a later settings stage.',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _showLater(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Go back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                isOwnProfile
                    ? AppPaths.repairerDashboard
                    : AppPaths.customerHome,
              );
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isOwnProfile ? 'Business profile' : 'Repairer profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.industrial,
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            height: 78,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [LiquidGlassColors.industrial, LiquidGlassColors.cyan],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: profile.logoUrl == null
                ? const Icon(
                    Icons.handyman_rounded,
                    color: Colors.white,
                    size: 36,
                  )
                : CachedNetworkImage(
                    imageUrl: profile.logoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(
                      Icons.handyman_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.businessName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(profile.fullName),
                const SizedBox(height: 10),
                LiquidGlassStatusPill(
                  label: profile.isVerified ? 'Verified' : 'Under review',
                  status: profile.isVerified
                      ? LiquidGlassStatus.success
                      : LiquidGlassStatus.warning,
                ),
                const SizedBox(height: 7),
                Text(
                  profile.isVerified
                      ? 'Identity and business verified'
                      : 'Business verification is under review',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetrics extends StatelessWidget {
  const _ProfileMetrics({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        label: 'Rating',
        value:
            '${profile.averageRating.toStringAsFixed(1)} (${profile.reviewCount})',
        icon: Icons.star_rounded,
      ),
      (
        label: 'Completed jobs',
        value: '${profile.completedJobCount}',
        icon: Icons.task_alt_rounded,
      ),
      (
        label: 'Response rate',
        value: '${profile.responseRate.round()}%',
        icon: Icons.bolt_rounded,
      ),
      (
        label: 'Experience',
        value: '${profile.yearsExperience} years',
        icon: Icons.workspace_premium_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth < 420 ? 1.25 : 1.55,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return LiquidGlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(metric.icon, color: LiquidGlassColors.industrial),
                  const Spacer(),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    metric.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.glassColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 9),
          Text(profile.description),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.mobileRepairAvailable)
                const LiquidGlassChip(
                  label: 'Mobile repair',
                  icon: Icons.home_repair_service_rounded,
                  selected: true,
                ),
              if (profile.collectionServiceAvailable)
                const LiquidGlassChip(
                  label: 'Collection service',
                  icon: Icons.local_shipping_outlined,
                  selected: true,
                ),
              if (profile.emergencyServiceAvailable)
                const LiquidGlassChip(
                  label: 'Emergency availability',
                  icon: Icons.emergency_outlined,
                  selected: true,
                  accent: LiquidGlassColors.amber,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecialisationsCard extends StatelessWidget {
  const _SpecialisationsCard({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repair specialisations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 13),
          if (profile.specialisations.isEmpty)
            const Text('General repair services')
          else
            for (final item in profile.specialisations) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 21,
                    color: LiquidGlassColors.industrial,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            item.category,
                            if (item.subcategory != null) item.subcategory!,
                            if (item.yearsExperience != null)
                              '${item.yearsExperience} years',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.glassColors.secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item != profile.specialisations.last)
                const Divider(height: 26),
            ],
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service coverage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final area in profile.serviceAreas) ...[
            _InfoRow(icon: Icons.location_on_outlined, text: area.name),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.radar_rounded,
              text: '${area.radiusKilometres.toStringAsFixed(0)} km radius',
            ),
          ],
          if (profile.serviceAreas.isEmpty)
            _InfoRow(
              icon: Icons.radar_rounded,
              text:
                  '${profile.serviceRadiusKilometres.toStringAsFixed(0)} km service radius',
            ),
          const SizedBox(height: 12),
          Text(
            'The precise business and customer addresses are not displayed here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.glassColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Availability', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.schedule_rounded, text: profile.workingHours),
          for (final slot in profile.availability) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.event_available_outlined, text: slot),
          ],
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.search_rounded,
            text:
                'Inspection from ${NumberFormat.simpleCurrency(name: profile.currencyCode).format(profile.inspectionFeeMinor / 100)}',
          ),
        ],
      ),
    );
  }
}

class _QualificationsCard extends StatelessWidget {
  const _QualificationsCard({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final entries = [...profile.qualifications, ...profile.certifications];
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qualifications and verified credentials',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 13),
          if (entries.isEmpty)
            const Text('No public credentials supplied.')
          else
            for (final entry in entries) ...[
              _InfoRow(icon: Icons.verified_outlined, text: entry),
              const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: LiquidGlassColors.industrial),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 42),
              const SizedBox(height: 14),
              Text(
                'Profile unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              LiquidGlassButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

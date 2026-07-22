import 'dart:async';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/controllers/repairer_marketplace_state.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/marketplace_request_card.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RepairerDashboardScreen extends ConsumerWidget {
  const RepairerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repairerMarketplaceControllerProvider);
    final dashboard = state.dashboard;
    return Scaffold(
      extendBody: true,
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: Stack(
          children: [
            if (dashboard == null)
              _InitialState(state: state)
            else
              RefreshIndicator(
                onRefresh: () => ref
                    .read(repairerMarketplaceControllerProvider.notifier)
                    .loadDashboard(refresh: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1160),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                132,
                              ),
                              child: _DashboardContent(
                                dashboard: dashboard,
                                errorMessage: state.errorMessage,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const RepairerMarketplaceNavigation(selectedIndex: 0),
          ],
        ),
      ),
    );
  }
}

class _InitialState extends ConsumerWidget {
  const _InitialState({required this.state});

  final RepairerMarketplaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.phase != RepairerMarketplacePhase.failure) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading your repair marketplace',
        ),
      );
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: LiquidGlassColors.industrial,
                ),
                const SizedBox(height: 16),
                Text(
                  'Marketplace unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage ?? 'Please try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                LiquidGlassButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => unawaited(
                    ref
                        .read(repairerMarketplaceControllerProvider.notifier)
                        .loadDashboard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.dashboard, this.errorMessage});

  final RepairerDashboardSummary dashboard;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardHeader(profile: profile),
        if (errorMessage != null) ...[
          const SizedBox(height: 18),
          _InlineNotice(message: errorMessage!),
        ],
        const SizedBox(height: 28),
        Text(
          'Good morning, ${profile.fullName.split(' ').first}',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Your best marketplace opportunities, ranked for your business.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
        if (!profile.isVerified) ...[
          const SizedBox(height: 18),
          const _VerificationNotice(),
        ],
        const SizedBox(height: 26),
        _DashboardMetrics(dashboard: dashboard),
        const SizedBox(height: 32),
        _SectionTitle(
          title: 'New matching requests',
          supporting: '${dashboard.newMatchCount} eligible requests',
          actionLabel: 'View all',
          onAction: () => context.go(AppPaths.repairerRequests),
        ),
        const SizedBox(height: 14),
        if (dashboard.matches.isEmpty)
          const _EmptyMatches()
        else
          ...dashboard.matches.indexed.expand(
            (entry) => [
              MarketplaceRequestCard(
                request: entry.$2,
                compact: true,
                onTap: () =>
                    context.go(AppPaths.repairerRequestFor(entry.$2.id)),
              ),
              if (entry.$1 != dashboard.matches.length - 1)
                const SizedBox(height: 14),
            ],
          ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final work = _WorkSnapshot(dashboard: dashboard);
            final performance = _MarketplacePerformance(profile: profile);
            if (constraints.maxWidth < 760) {
              return Column(
                children: [work, const SizedBox(height: 14), performance],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: work),
                const SizedBox(width: 14),
                Expanded(child: performance),
              ],
            );
          },
        ),
        if (dashboard.monthEarningsMinor > 0) ...[
          const SizedBox(height: 14),
          _EarningsSummary(amountMinor: dashboard.monthEarningsMinor),
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LiquidGlassColors.industrial, LiquidGlassColors.cyan],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(Icons.handyman_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FixBrief Pro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                profile.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.glassColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 4),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.dashboard});

  final RepairerDashboardSummary dashboard;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        label: 'New matches',
        value: '${dashboard.newMatchCount}',
        icon: Icons.auto_awesome_rounded,
        color: LiquidGlassColors.industrial,
      ),
      (
        label: 'Nearby',
        value: '${dashboard.nearbyCount}',
        icon: Icons.near_me_rounded,
        color: LiquidGlassColors.coolBlue,
      ),
      (
        label: 'High urgency',
        value: '${dashboard.highUrgencyCount}',
        icon: Icons.bolt_rounded,
        color: LiquidGlassColors.amber,
      ),
      (
        label: 'Average rating',
        value: dashboard.profile.averageRating.toStringAsFixed(1),
        icon: Icons.star_rounded,
        color: LiquidGlassColors.appliances,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 430 ? 1.2 : 1.65,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(metric.icon, color: metric.color, size: 24),
                  const Spacer(),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.supporting,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String supporting;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                supporting,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.glassColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _WorkSnapshot extends StatelessWidget {
  const _WorkSnapshot({required this.dashboard});

  final RepairerDashboardSummary dashboard;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Work snapshot', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          _SummaryRow(
            icon: Icons.request_quote_outlined,
            label: 'Quotes awaiting response',
            value: '${dashboard.submittedQuoteCount}',
            onTap: () => context.go(AppPaths.repairerQuotes),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.handyman_outlined,
            label: 'Active jobs',
            value: '${dashboard.activeJobCount}',
            onTap: () => context.go(AppPaths.repairerJobs),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            label: "Today's appointments",
            value: '${dashboard.todayAppointmentCount}',
          ),
        ],
      ),
    );
  }
}

class _MarketplacePerformance extends StatelessWidget {
  const _MarketplacePerformance({required this.profile});

  final RepairerMarketplaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Marketplace profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              LiquidGlassStatusPill(
                label: profile.isVerified ? 'Verified' : 'Under review',
                status: profile.isVerified
                    ? LiquidGlassStatus.success
                    : LiquidGlassStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryRow(
            icon: Icons.bolt_rounded,
            label: 'Response rate',
            value: '${profile.responseRate.round()}%',
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.task_alt_rounded,
            label: 'Quote acceptance',
            value: '${profile.quoteAcceptanceRate.round()}%',
          ),
          const SizedBox(height: 16),
          LiquidGlassButton(
            label: 'View business profile',
            icon: Icons.storefront_rounded,
            expand: true,
            level: LiquidGlassButtonLevel.secondary,
            onPressed: () => context.go(AppPaths.repairerProfileFor('me')),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: onTap == null
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: LiquidGlassColors.industrial),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  const _EarningsSummary({required this.amountMinor});

  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.simpleCurrency(
      name: 'GBP',
      decimalDigits: 0,
    ).format(amountMinor / 100);
    return LiquidGlassCard(
      tint: LiquidGlassColors.industrial,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            color: LiquidGlassColors.industrial,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed-job value this month',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 3),
                Text(amount, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return const LiquidGlassCard(
      padding: EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'No eligible requests right now. New requests will appear when they match your services and area.',
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    return const LiquidGlassCard(
      tint: LiquidGlassColors.amber,
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: LiquidGlassColors.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your business verification is under review. Matching requests unlock after approval.',
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.amber,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

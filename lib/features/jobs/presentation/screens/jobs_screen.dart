import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/presentation/providers/job_providers.dart';
import 'package:fixbrief/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    final jobs = ref.watch(jobsProvider);
    final isRepairer = role == UserRole.repairer;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(isRepairer ? 'Jobs' : 'My repairs'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          const NotificationBell(),
          if (isRepairer)
            IconButton(
              tooltip: 'My quotes',
              onPressed: () => context.go(AppPaths.repairerQuotes),
              icon: const Icon(Icons.request_quote_outlined),
            ),
        ],
      ),
      body: FluidBackground(
        accent: isRepairer
            ? LiquidGlassColors.industrial
            : LiquidGlassColors.vehicles,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(jobsProvider);
                await ref.read(jobsProvider.future);
              },
              child: jobs.when(
                loading: () => const _LoadingJobs(),
                error: (error, stackTrace) => _JobsError(
                  message: error is JobFailure
                      ? error.message
                      : 'Jobs could not be loaded. Try again.',
                  onRetry: () => ref.invalidate(jobsProvider),
                ),
                data: (items) => _JobsList(items: items, role: role),
              ),
            ),
            if (isRepairer)
              const RepairerMarketplaceNavigation(selectedIndex: 2)
            else
              const _CustomerJobsNavigation(),
          ],
        ),
      ),
    );
  }
}

class _JobsList extends StatelessWidget {
  const _JobsList({required this.items, required this.role});

  final List<RepairJob> items;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
        children: const [
          LiquidGlassCard(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.handyman_outlined, size: 46),
                SizedBox(height: 16),
                Text('No jobs yet'),
                SizedBox(height: 8),
                Text(
                  'A job appears here after a quote is accepted.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }
    final active = items.where((job) => !job.status.isTerminal).toList();
    final history = items.where((job) => job.status.isTerminal).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      children: [
        Text(
          role == UserRole.customer
              ? 'Track each repair from accepted quote to completion.'
              : 'Update progress so customers always know what happens next.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Active jobs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final job in active) ...[
            _JobCard(job: job, role: role),
            const SizedBox(height: 14),
          ],
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Repair history', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final job in history) ...[
            _JobCard(job: job, role: role),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.role});

  final RepairJob job;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(
      name: job.currencyCode,
      decimalDigits: 0,
    );
    final range =
        '${formatter.format(job.agreedMinimumMinor / 100)}\u2013${formatter.format(job.agreedMaximumMinor / 100)}';
    return LiquidGlassCard(
      semanticLabel: '${job.itemName}, ${job.status.label}',
      onTap: () => context.go(
        role == UserRole.customer
            ? AppPaths.customerJobFor(job.id)
            : AppPaths.repairerJobFor(job.id),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: LiquidGlassColors.vehicles.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  color: LiquidGlassColors.vehicles,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.itemName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job.counterpartName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              LiquidGlassStatusPill(
                label: job.status.label,
                status: _statusStyle(job.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 19),
              const SizedBox(width: 8),
              Text(range),
              const Spacer(),
              Text(
                DateFormat('d MMM').format(job.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (job.canReview) ...[
            const SizedBox(height: 14),
            const Text(
              'Review available',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

LiquidGlassStatus _statusStyle(JobStatus status) => switch (status) {
  JobStatus.completed => LiquidGlassStatus.success,
  JobStatus.cancelled || JobStatus.disputed => LiquidGlassStatus.danger,
  JobStatus.waitingForParts => LiquidGlassStatus.warning,
  _ => LiquidGlassStatus.info,
};

class _LoadingJobs extends StatelessWidget {
  const _LoadingJobs();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading jobs'),
    );
  }
}

class _JobsError extends StatelessWidget {
  const _JobsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
      children: [
        LiquidGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerJobsNavigation extends StatelessWidget {
  const _CustomerJobsNavigation();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LiquidGlassNavigationBar(
          selectedIndex: 1,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go(AppPaths.customerHome);
                return;
              case 1:
                return;
              case 2:
                context.go(AppPaths.conversations);
                return;
              case 3:
                context.go(AppPaths.profile);
                return;
            }
          },
          destinations: const [
            LiquidGlassNavigationDestination(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
            LiquidGlassNavigationDestination(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
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
    );
  }
}

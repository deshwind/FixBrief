import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/presentation/providers/quote_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RepairerQuotesScreen extends ConsumerWidget {
  const RepairerQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(repairerQuotesProvider);
    return Scaffold(
      extendBody: true,
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: quotes.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading your provisional quotes',
                  ),
                ),
                error: (error, stackTrace) => _QuotesError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(repairerQuotesProvider),
                ),
                data: (values) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(repairerQuotesProvider),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                132,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _QuotesHeader(),
                                  const SizedBox(height: 26),
                                  Text(
                                    'Your quotes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    'Track drafts, submitted estimates, expiry, and customer decisions.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color:
                                              context.glassColors.secondaryText,
                                        ),
                                  ),
                                  const SizedBox(height: 22),
                                  if (values.isEmpty)
                                    const _EmptyQuotes()
                                  else
                                    for (final (index, quote)
                                        in values.indexed) ...[
                                      _RepairerQuoteCard(quote: quote),
                                      if (index != values.length - 1)
                                        const SizedBox(height: 14),
                                    ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const RepairerMarketplaceNavigation(selectedIndex: 2),
          ],
        ),
      ),
    );
  }
}

class _QuotesHeader extends StatelessWidget {
  const _QuotesHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: LiquidGlassColors.industrial.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.request_quote_rounded,
            color: LiquidGlassColors.industrial,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'FixBrief Pro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _RepairerQuoteCard extends StatelessWidget {
  const _RepairerQuoteCard({required this.quote});

  final ProvisionalQuote quote;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: quote.canEdit,
      label:
          '${quote.itemName ?? 'Repair request'}, ${quote.status.label} quote',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go(AppPaths.repairerQuoteFor(quote.requestId)),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.itemName ?? 'Repair request',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (quote.categoryName != null)
                          Text(
                            [
                              quote.categoryName,
                              quote.approximateArea,
                            ].whereType<String>().join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.glassColors.secondaryText,
                                ),
                          ),
                      ],
                    ),
                  ),
                  LiquidGlassStatusPill(
                    label: quote.status.label,
                    status: _status(quote.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_money(quote.totalMinimumMinor)}–${_money(quote.totalMaximumMinor)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                provisionalEstimateWarning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.glassColors.secondaryText,
                ),
              ),
              if (quote.expiresAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  quote.isExpired
                      ? 'Expired ${DateFormat('d MMM yyyy').format(quote.expiresAt!)}'
                      : 'Expires ${DateFormat('d MMM yyyy').format(quote.expiresAt!)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQuotes extends StatelessWidget {
  const _EmptyQuotes();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          const Icon(
            Icons.request_quote_outlined,
            size: 48,
            color: LiquidGlassColors.industrial,
          ),
          const SizedBox(height: 14),
          Text('No quotes yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          const Text(
            'Open a matching request and prepare a transparent provisional estimate.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          LiquidGlassButton(
            label: 'Find matching requests',
            icon: Icons.manage_search_rounded,
            onPressed: () => context.go(AppPaths.repairerRequests),
          ),
        ],
      ),
    );
  }
}

class _QuotesError extends StatelessWidget {
  const _QuotesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

LiquidGlassStatus _status(QuoteStatus status) => switch (status) {
  QuoteStatus.accepted => LiquidGlassStatus.success,
  QuoteStatus.draft || QuoteStatus.submitted => LiquidGlassStatus.info,
  _ => LiquidGlassStatus.warning,
};

String _money(int minor) => NumberFormat.simpleCurrency(
  locale: 'en_GB',
  decimalDigits: minor % 100 == 0 ? 0 : 2,
).format(minor / 100);

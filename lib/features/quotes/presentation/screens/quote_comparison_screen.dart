import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_dialog.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/presentation/providers/quote_providers.dart';
import 'package:fixbrief/features/quotes/presentation/widgets/provisional_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class QuoteComparisonScreen extends ConsumerStatefulWidget {
  const QuoteComparisonScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<QuoteComparisonScreen> createState() =>
      _QuoteComparisonScreenState();
}

class _QuoteComparisonScreenState extends ConsumerState<QuoteComparisonScreen> {
  String? _acceptingQuoteId;

  @override
  Widget build(BuildContext context) {
    final comparison = ref.watch(quoteComparisonProvider(widget.requestId));
    return Scaffold(
      body: FluidBackground(
        accent: LiquidGlassColors.coolBlue,
        child: SafeArea(
          child: comparison.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading quote comparison',
              ),
            ),
            error: (error, stackTrace) => _ComparisonError(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(quoteComparisonProvider(widget.requestId)),
            ),
            data: (value) => _buildComparison(context, value),
          ),
        ),
      ),
    );
  }

  Widget _buildComparison(BuildContext context, QuoteComparison comparison) {
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(quoteComparisonProvider(widget.requestId)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ComparisonHeader(),
                      const SizedBox(height: 24),
                      Text(
                        'Compare quotes',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        comparison.itemName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Compare price, trust, experience, availability, and warranty—not price alone.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.glassColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const ProvisionalWarningCard(),
                      if (comparison.hasAcceptedQuote) ...[
                        const SizedBox(height: 16),
                        _AcceptedBanner(jobId: comparison.jobId),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${comparison.quotes.length} repairer estimates',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const LiquidGlassChip(
                            label: 'Overall fit ordering',
                            icon: Icons.balance_rounded,
                            selected: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (comparison.quotes.isEmpty)
                        const _EmptyComparison()
                      else
                        for (final (index, quote)
                            in comparison.quotes.indexed) ...[
                          _ComparisonQuoteCard(
                            quote: quote,
                            acceptedQuoteId: comparison.acceptedQuoteId,
                            isAccepting: _acceptingQuoteId == quote.id,
                            onAccept: () => _confirmAccept(quote),
                          ),
                          if (index != comparison.quotes.length - 1)
                            const SizedBox(height: 16),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAccept(ProvisionalQuote quote) async {
    final confirmed = await showLiquidGlassDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accept ${quote.businessName}’s quote?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'You are selecting an estimated range of ${_money(quote.totalMinimumMinor)}–${_money(quote.totalMaximumMinor)}.',
          ),
          const SizedBox(height: 12),
          const Text(
            provisionalEstimateWarning,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Other submitted quotes will be marked as not selected and a repair job will be created.',
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep comparing'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Accept quote'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _acceptingQuoteId = quote.id);
    try {
      await ref
          .read(quoteRepositoryProvider)
          .acceptQuote(
            quote.id,
            idempotencyKey:
                'accept-${quote.id}-${DateTime.now().microsecondsSinceEpoch}',
          );
      ref.invalidate(quoteComparisonProvider(widget.requestId));
      if (!mounted) {
        return;
      }
      setState(() => _acceptingQuoteId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${quote.businessName}’s quote was accepted.')),
      );
    } on QuoteFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _acceptingQuoteId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: context.glassColors.danger,
        ),
      );
    }
  }
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back home',
          onPressed: () => context.go(AppPaths.customerHome),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'FixBrief quotes',
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

class _ComparisonQuoteCard extends StatelessWidget {
  const _ComparisonQuoteCard({
    required this.quote,
    required this.acceptedQuoteId,
    required this.isAccepting,
    required this.onAccept,
  });

  final ProvisionalQuote quote;
  final String? acceptedQuoteId;
  final bool isAccepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final selected = acceptedQuoteId == quote.id;
    return LiquidGlassCard(
      tint: selected
          ? context.glassColors.success
          : quote.isRecommended
          ? LiquidGlassColors.coolBlue
          : null,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote.isRecommended && acceptedQuoteId == null) ...[
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: LiquidGlassColors.coolBlue,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    quote.recommendationLabel ?? 'Strong overall fit',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: LiquidGlassColors.industrial.withValues(
                  alpha: 0.16,
                ),
                child: const Icon(
                  Icons.car_repair_rounded,
                  color: LiquidGlassColors.industrial,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.businessName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${quote.averageRating.toStringAsFixed(1)} ★ · ${quote.reviewCount} reviews',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                const LiquidGlassStatusPill(
                  label: 'Accepted',
                  status: LiquidGlassStatus.success,
                )
              else if (quote.isVerified)
                const LiquidGlassStatusPill(
                  label: 'Verified',
                  status: LiquidGlassStatus.success,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${_money(quote.totalMinimumMinor)}–${_money(quote.totalMaximumMinor)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Inspection fee ${_money(quote.inspectionFeeMinor)}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const Divider(height: 28),
          _MetricGrid(quote: quote),
          if (quote.qualifications.isNotEmpty) ...[
            const SizedBox(height: 15),
            for (final qualification in quote.qualifications) ...[
              _Qualification(text: qualification),
              const SizedBox(height: 7),
            ],
          ],
          if (quote.isRecommended &&
              quote.recommendationReasons.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text(
              'Why this is a strong fit',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final reason in quote.recommendationReasons) ...[
              _Reason(text: reason),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 2),
            Text(
              'This considers trust and service fit. It is not a cheapest-quote label.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.glassColors.secondaryText,
              ),
            ),
          ],
          if (quote.additionalComments != null) ...[
            const Divider(height: 28),
            Text(
              'Repairer notes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(quote.additionalComments!),
          ],
          const SizedBox(height: 16),
          Text(
            provisionalEstimateWarning,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.glassColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      context.go(AppPaths.repairerProfileFor(quote.repairerId)),
                  child: const Text('View profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: LiquidGlassButton(
                  label: selected
                      ? 'Quote accepted'
                      : quote.isExpired
                      ? 'Quote expired'
                      : quote.status == QuoteStatus.rejected
                      ? 'Not selected'
                      : 'Accept quote',
                  icon: selected
                      ? Icons.check_circle_rounded
                      : Icons.handshake_outlined,
                  isLoading: isAccepting,
                  expand: true,
                  onPressed: acceptedQuoteId == null && quote.canAccept
                      ? onAccept
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.quote});

  final ProvisionalQuote quote;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Completed jobs', '${quote.completedJobCount}', Icons.handyman_outlined),
      (
        'Distance',
        quote.distanceKilometres == null
            ? 'Service area'
            : '${quote.distanceKilometres!.toStringAsFixed(1)} km',
        Icons.near_me_outlined,
      ),
      (
        'Availability',
        quote.earliestAvailability == null
            ? 'Ask repairer'
            : DateFormat('d MMM').format(quote.earliestAvailability!),
        Icons.event_available_outlined,
      ),
      (
        'Warranty',
        quote.warrantyDays == 0 ? 'None listed' : '${quote.warrantyDays} days',
        Icons.verified_user_outlined,
      ),
      ('Response rate', '${quote.responseRate.round()}%', Icons.speed_rounded),
      (
        'Duration',
        '${(quote.estimatedDurationMinutes / 60).toStringAsFixed(1)} hours',
        Icons.schedule_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 650
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      value.$3,
                      size: 19,
                      color: LiquidGlassColors.industrial,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            value.$2,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 18,
          color: LiquidGlassColors.coolBlue,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Qualification extends StatelessWidget {
  const _Qualification({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.workspace_premium_outlined,
          size: 18,
          color: LiquidGlassColors.industrial,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _AcceptedBanner extends StatelessWidget {
  const _AcceptedBanner({this.jobId});

  final String? jobId;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: context.glassColors.success,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.glassColors.success),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Quote accepted. Your repair job has been created.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyComparison extends StatelessWidget {
  const _EmptyComparison();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(26),
      child: const Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 46),
          SizedBox(height: 13),
          Text(
            'No active quotes yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          SizedBox(height: 7),
          Text(
            'Verified repairers can still review your privacy-safe brief. Pull down to check again.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ComparisonError extends StatelessWidget {
  const _ComparisonError({required this.message, required this.onRetry});

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
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
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

String _money(int minor) => NumberFormat.simpleCurrency(
  locale: 'en_GB',
  decimalDigits: minor % 100 == 0 ? 0 : 2,
).format(minor / 100);

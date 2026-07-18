import 'package:cached_network_image/cached_network_image.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MarketplaceRequestDetailScreen extends ConsumerWidget {
  const MarketplaceRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(marketplaceRequestDetailProvider(requestId));
    return Scaffold(
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: SafeArea(
          child: detail.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading repair request details',
              ),
            ),
            error: (error, stackTrace) => _RequestError(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(marketplaceRequestDetailProvider(requestId)),
            ),
            data: (value) => _RequestDetail(value: value),
          ),
        ),
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  const _RequestDetail({required this.value});

  final MarketplaceRequestDetail value;

  @override
  Widget build(BuildContext context) {
    final request = value.request;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DetailHeader(),
                    const SizedBox(height: 24),
                    _PrivacyBanner(value: value),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.categoryLine,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: LiquidGlassColors.industrial),
                          ),
                        ),
                        LiquidGlassStatusPill(
                          label: request.urgency.label,
                          status: request.urgency.isHighPriority
                              ? LiquidGlassStatus.warning
                              : LiquidGlassStatus.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.itemName,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Published ${DateFormat('d MMM, HH:mm').format(request.publishedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.glassColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MatchExplanation(request: request),
                    if (request.stopUsingItem ||
                        request.safetyRisk == 'high' ||
                        request.safetyRisk == 'critical') ...[
                      const SizedBox(height: 16),
                      _HighRiskWarning(assessment: value.assessment),
                    ],
                    const SizedBox(height: 16),
                    _RequestBrief(value: value),
                    const SizedBox(height: 16),
                    if (value.assessment case final assessment?)
                      _AssessmentCard(assessment: assessment),
                    if (value.assessment != null) const SizedBox(height: 16),
                    _ServiceRequirements(value: value),
                    const SizedBox(height: 16),
                    _EvidenceCard(evidence: value.evidence),
                    const SizedBox(height: 22),
                    LiquidGlassButton(
                      label: 'Prepare or edit provisional quote',
                      icon: Icons.request_quote_rounded,
                      expand: true,
                      onPressed: () =>
                          context.go(AppPaths.repairerQuoteFor(request.id)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A final price should only be confirmed after any required physical inspection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.glassColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back to matching requests',
          onPressed: () => context.go(AppPaths.repairerRequests),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Privacy-safe marketplace view',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.glassColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.value});

  final MarketplaceRequestDetail value;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.coolBlue,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_rounded,
            color: LiquidGlassColors.coolBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.request.approximateArea,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(value.privacyNotice),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchExplanation extends StatelessWidget {
  const _MatchExplanation({required this.request});

  final MarketplaceRequest request;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.industrial,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: LiquidGlassColors.industrial,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${request.matchScore.round()}% marketplace match',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (request.matchReasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final reason in request.matchReasons) ...[
              _Bullet(icon: Icons.check_circle_outline_rounded, text: reason),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _HighRiskWarning extends StatelessWidget {
  const _HighRiskWarning({required this.assessment});

  final MarketplaceAssessment? assessment;

  @override
  Widget build(BuildContext context) {
    final danger = context.glassColors.danger;
    return Semantics(
      liveRegion: true,
      label: 'Serious safety warning',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: danger, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded, color: danger, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety-critical request',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: danger),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assessment?.safetyWarning ??
                        'The customer has been advised to stop using this item pending a professional inspection.',
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

class _RequestBrief extends StatelessWidget {
  const _RequestBrief({required this.value});

  final MarketplaceRequestDetail value;

  @override
  Widget build(BuildContext context) {
    final itemDetails = [
      value.brand,
      value.model,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer-approved repair brief',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (itemDetails.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(itemDetails, style: Theme.of(context).textTheme.labelLarge),
          ],
          const SizedBox(height: 12),
          Text(value.problemDescription),
          if (value.repairBrief.isNotEmpty) ...[
            const Divider(height: 30),
            Text(
              'Professional brief',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 7),
            Text(value.repairBrief),
          ],
          if (value.symptoms.isNotEmpty) ...[
            const Divider(height: 30),
            Text(
              'Reported symptoms',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 9),
            for (final symptom in value.symptoms) ...[
              _Bullet(icon: Icons.notes_rounded, text: symptom),
              const SizedBox(height: 7),
            ],
          ],
          if (value.previousRepairs case final repairs?) ...[
            const Divider(height: 30),
            Text(
              'Previous repair context',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 7),
            Text(repairs),
          ],
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment});

  final MarketplaceAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.appliances,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: LiquidGlassColors.appliances,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assessment.disclaimer,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(assessment.summary),
          if (assessment.possibleCauses.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Possible inspection areas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Confidence indicators organise the intake information; they are not diagnostic certainty.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.glassColors.secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            for (final cause in assessment.possibleCauses) ...[
              Text(
                '${cause.cause} · ${(cause.confidence * 100).round()}% indication',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (cause.reason.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(cause.reason),
              ],
              const SizedBox(height: 11),
            ],
          ],
          if (assessment.inspectionRecommendation case final recommendation?)
            _Bullet(icon: Icons.search_rounded, text: recommendation),
        ],
      ),
    );
  }
}

class _ServiceRequirements extends StatelessWidget {
  const _ServiceRequirements({required this.value});

  final MarketplaceRequestDetail value;

  @override
  Widget build(BuildContext context) {
    final request = value.request;
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service requirements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              if (request.inspectionRequired)
                const LiquidGlassChip(
                  label: 'Inspection required',
                  icon: Icons.search_rounded,
                  selected: true,
                ),
              if (request.mobileRepairRequired)
                const LiquidGlassChip(
                  label: 'Mobile repair',
                  icon: Icons.home_repair_service_rounded,
                  selected: true,
                ),
              if (request.collectionRequired)
                const LiquidGlassChip(
                  label: 'Collection needed',
                  icon: Icons.local_shipping_outlined,
                  selected: true,
                ),
              if (value.preferredDate case final date?)
                LiquidGlassChip(
                  label: 'Preferred ${DateFormat.MMMd().format(date)}',
                  icon: Icons.event_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final List<MarketplaceEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer evidence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            evidence.isEmpty
                ? 'No evidence was shared with eligible repairers.'
                : 'Evidence is visible because the customer approved marketplace sharing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.glassColors.secondaryText,
            ),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in evidence)
                      SizedBox(
                        width: width,
                        child: _EvidenceTile(item: item),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item});

  final MarketplaceEvidence item;

  @override
  Widget build(BuildContext context) {
    final isImage = item.kind == 'image' && item.signedUrl != null;
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LiquidGlassColors.industrial.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidGlassColors.industrial.withValues(alpha: 0.25),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isImage)
            CachedNetworkImage(
              imageUrl: item.signedUrl!,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  _EvidenceIcon(kind: item.kind),
            )
          else
            _EvidenceIcon(kind: item.kind),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.62),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                item.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceIcon extends StatelessWidget {
  const _EvidenceIcon({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      'video' => Icons.play_circle_outline_rounded,
      'audio' => Icons.graphic_eq_rounded,
      'image' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };
    return Center(
      child: Icon(icon, size: 52, color: LiquidGlassColors.industrial),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: LiquidGlassColors.industrial),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.message, required this.onRetry});

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
              const Icon(Icons.lock_outline_rounded, size: 42),
              const SizedBox(height: 14),
              Text(
                'Request unavailable',
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
              TextButton(
                onPressed: () => context.go(AppPaths.repairerRequests),
                child: const Text('Back to matching requests'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

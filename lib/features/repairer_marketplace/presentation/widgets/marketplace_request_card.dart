import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MarketplaceRequestCard extends StatelessWidget {
  const MarketplaceRequestCard({
    required this.request,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  final MarketplaceRequest request;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(request.categoryId);
    return LiquidGlassCard(
      semanticLabel:
          '${request.itemName}, ${request.urgency.label}, ${request.approximateArea}',
      onTap: onTap,
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
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_categoryIcon(request.categoryId), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.categoryLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: accent),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${request.matchScore.round()}% match',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LiquidGlassStatusPill(
                label: request.urgency.label,
                status: request.urgency.isHighPriority
                    ? LiquidGlassStatus.warning
                    : LiquidGlassStatus.info,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            request.itemName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            request.summary,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Metadata(
                icon: Icons.location_on_outlined,
                label: request.distanceKilometres == null
                    ? request.approximateArea
                    : '${request.approximateArea} · ${request.distanceKilometres!.toStringAsFixed(1)} km',
              ),
              _Metadata(
                icon: Icons.schedule_rounded,
                label: _relativeTime(request.publishedAt),
              ),
              if (request.evidenceCount > 0)
                _Metadata(
                  icon: Icons.attach_file_rounded,
                  label:
                      '${request.evidenceCount} evidence ${request.evidenceCount == 1 ? 'item' : 'items'}',
                ),
            ],
          ),
          if (!compact && request.matchReasons.isNotEmpty) ...[
            const SizedBox(height: 15),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.matchReasons.take(2).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 17,
                color: context.glassColors.secondaryText,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Exact address and customer identity hidden',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.glassColors.secondaryText,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: context.glassColors.secondaryText),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.isNegative) {
    return DateFormat.MMMd().format(value);
  }
  if (difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} d ago';
  }
  return DateFormat.MMMd().format(value);
}

IconData _categoryIcon(String categoryId) {
  final value = categoryId.toLowerCase();
  if (value.contains('vehicle')) {
    return Icons.directions_car_filled_rounded;
  }
  if (value.contains('computer') || value.contains('laptop')) {
    return Icons.laptop_mac_rounded;
  }
  if (value.contains('appliance')) {
    return Icons.local_laundry_service_rounded;
  }
  if (value.contains('plumb')) {
    return Icons.plumbing_rounded;
  }
  if (value.contains('bicycle')) {
    return Icons.pedal_bike_rounded;
  }
  if (value.contains('furniture')) {
    return Icons.chair_alt_rounded;
  }
  return Icons.handyman_rounded;
}

Color _categoryAccent(String categoryId) {
  final value = categoryId.toLowerCase();
  if (value.contains('vehicle')) {
    return LiquidGlassColors.vehicles;
  }
  if (value.contains('computer') || value.contains('laptop')) {
    return LiquidGlassColors.computers;
  }
  if (value.contains('appliance')) {
    return LiquidGlassColors.appliances;
  }
  if (value.contains('plumb')) {
    return LiquidGlassColors.coolBlue;
  }
  if (value.contains('bicycle')) {
    return LiquidGlassColors.softTeal;
  }
  if (value.contains('furniture')) {
    return LiquidGlassColors.amber;
  }
  return LiquidGlassColors.industrial;
}

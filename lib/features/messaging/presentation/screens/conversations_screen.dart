import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:fixbrief/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final role = ref.watch(authSessionControllerProvider).onboarding.role;
    final isRepairer = role == UserRole.repairer;
    return Scaffold(
      extendBody: isRepairer,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        accent: LiquidGlassColors.computers,
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: conversations.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading conversations',
                  ),
                ),
                error: (error, stackTrace) => _ConversationError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
                data: (items) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(conversationsProvider),
                  child: items.isEmpty
                      ? const _EmptyConversations()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            16,
                            20,
                            isRepairer ? 132 : 32,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _ConversationTile(conversation: items[index]),
                        ),
                ),
              ),
            ),
            if (isRepairer)
              const RepairerMarketplaceNavigation(selectedIndex: 3),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final timestamp = conversation.lastMessageAt;
    return Semantics(
      button: true,
      label:
          'Conversation with ${conversation.counterpartName}, ${conversation.unreadCount} unread messages',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go(
          AppPaths.conversationFor(conversation.id),
          extra: conversation,
        ),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: LiquidGlassColors.computers.withValues(
                  alpha: 0.16,
                ),
                foregroundColor: LiquidGlassColors.computers,
                child: Text(
                  conversation.counterpartName.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.counterpartName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: conversation.unreadCount > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _friendlyTime(timestamp),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.glassColors.secondaryText,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        conversation.itemName ?? 'Repair request',
                        conversation.approximateArea,
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.glassColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (conversation.isBlocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: LiquidGlassStatusPill(
                              label: 'Blocked',
                              status: LiquidGlassStatus.danger,
                            ),
                          )
                        else if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 10),
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (DateUtils.isSameDay(local, now)) {
      return DateFormat.jm().format(local);
    }
    if (local.isAfter(now.subtract(const Duration(days: 6)))) {
      return DateFormat.E().format(local);
    }
    return DateFormat.MMMd().format(local);
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.forum_outlined,
          size: 64,
          color: LiquidGlassColors.computers.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 20),
        Text(
          'No conversations yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'A conversation opens when a repair professional submits a quote or contact is authorised.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _ConversationError extends StatelessWidget {
  const _ConversationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

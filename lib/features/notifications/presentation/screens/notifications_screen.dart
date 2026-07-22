import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';
import 'package:fixbrief/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push(AppPaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: FluidBackground(
        accent: role == UserRole.customer
            ? LiquidGlassColors.coolBlue
            : LiquidGlassColors.industrial,
        child: notifications.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading notifications',
            ),
          ),
          error: (error, stackTrace) => _NotificationError(
            message: error is NotificationFailure
                ? error.message
                : 'Notifications could not be loaded. Try again.',
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (items) => _NotificationList(
            items: items,
            role: role,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            onTap: (notification) =>
                _openNotification(context, ref, notification, role),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } on NotificationFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    FixBriefNotification notification,
    UserRole role,
  ) async {
    try {
      if (!notification.isRead) {
        await ref
            .read(notificationRepositoryProvider)
            .markRead(notification.id);
      }
      if (!context.mounted) {
        return;
      }
      final destination = _resolveDestination(notification.deepLink, role);
      if (destination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This update has no linked screen.')),
        );
        return;
      }
      await context.push(destination);
    } on NotificationFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.role,
    required this.onRefresh,
    required this.onTap,
  });

  final List<FixBriefNotification> items;
  final UserRole role;
  final Future<void> Function() onRefresh;
  final ValueChanged<FixBriefNotification> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          children: const [
            LiquidGlassCard(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 48),
                  SizedBox(height: 14),
                  Text('You are all caught up'),
                  SizedBox(height: 6),
                  Text(
                    'Quotes, messages, appointments, and job updates appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final today = DateUtils.dateOnly(DateTime.now());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final itemDay = DateUtils.dateOnly(item.createdAt);
          final previousDay = index == 0
              ? null
              : DateUtils.dateOnly(items[index - 1].createdAt);
          final showHeader = index == 0 || itemDay != previousDay;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                if (index > 0) const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    itemDay == today
                        ? 'Today'
                        : itemDay == today.subtract(const Duration(days: 1))
                        ? 'Yesterday'
                        : DateFormat('d MMMM y').format(item.createdAt),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
              _NotificationCard(item: item, onTap: () => onTap(item)),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final FixBriefNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(item.type);
    return LiquidGlassCard(
      semanticLabel:
          '${item.isRead ? 'Read' : 'Unread'} notification, ${item.title}',
      tint: item.isRead
          ? null
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(presentation.icon, color: presentation.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      Semantics(
                        label: 'Unread',
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(item.body),
                const SizedBox(height: 7),
                Text(
                  DateFormat('HH:mm').format(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (item.deepLink != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _presentation(FixBriefNotificationType type) =>
    switch (type) {
      FixBriefNotificationType.newQuote ||
      FixBriefNotificationType.quoteAccepted ||
      FixBriefNotificationType.quoteRejected ||
      FixBriefNotificationType.quoteExpiring => (
        icon: Icons.request_quote_outlined,
        color: LiquidGlassColors.softTeal,
      ),
      FixBriefNotificationType.newMessage => (
        icon: Icons.chat_bubble_outline_rounded,
        color: LiquidGlassColors.cyan,
      ),
      FixBriefNotificationType.inspectionProposed ||
      FixBriefNotificationType.appointmentConfirmed ||
      FixBriefNotificationType.appointmentReminder => (
        icon: Icons.calendar_month_outlined,
        color: LiquidGlassColors.appliances,
      ),
      FixBriefNotificationType.jobStatusUpdated ||
      FixBriefNotificationType.repairCompleted ||
      FixBriefNotificationType.reviewRequested => (
        icon: Icons.handyman_outlined,
        color: LiquidGlassColors.vehicles,
      ),
      FixBriefNotificationType.matchingRequest => (
        icon: Icons.manage_search_rounded,
        color: LiquidGlassColors.industrial,
      ),
      FixBriefNotificationType.unknown => (
        icon: Icons.notifications_none_rounded,
        color: LiquidGlassColors.neutralGrey,
      ),
    };

String? _resolveDestination(String? deepLink, UserRole role) {
  if (deepLink == null) {
    return null;
  }
  final uri = Uri.tryParse(deepLink);
  if (uri == null || uri.hasAuthority || !deepLink.startsWith('/')) {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length >= 4 &&
      segments[0] == 'customer' &&
      segments[1] == 'requests' &&
      segments[3] == 'quotes') {
    return role == UserRole.customer
        ? AppPaths.customerQuoteComparisonFor(segments[2])
        : null;
  }
  if (uri.path.startsWith('/repairer/quotes/')) {
    return role == UserRole.repairer ? AppPaths.repairerQuotes : null;
  }
  if (uri.path.startsWith('/customer')) {
    return role == UserRole.customer ? deepLink : null;
  }
  if (uri.path.startsWith('/repairer')) {
    return role == UserRole.repairer ? deepLink : null;
  }
  return uri.path.startsWith('/messages') ? deepLink : null;
}

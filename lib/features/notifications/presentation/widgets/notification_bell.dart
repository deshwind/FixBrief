import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : '$count unread notifications',
      onPressed: () => context.push(AppPaths.notifications),
      icon: count == 0
          ? const Icon(Icons.notifications_none_rounded)
          : Badge.count(
              count: count,
              isLabelVisible: true,
              child: const Icon(Icons.notifications_none_rounded),
            ),
    );
  }
}

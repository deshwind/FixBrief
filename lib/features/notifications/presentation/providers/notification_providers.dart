import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/notifications/data/repositories/demo_notification_repository.dart';
import 'package:fixbrief/features/notifications/data/repositories/supabase_notification_repository.dart';
import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';
import 'package:fixbrief/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final NotificationRepository repository;
  if (environment.useDemoAuthentication) {
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    repository = DemoNotificationRepository(role);
  } else {
    repository = SupabaseNotificationRepository(
      ref.watch(supabaseClientProvider),
    );
  }
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final notificationsProvider = StreamProvider<List<FixBriefNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).watchNotifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).asData?.value;
  return items?.where((notification) => !notification.isRead).length ?? 0;
});

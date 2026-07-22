import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';

abstract interface class NotificationRepository {
  Stream<List<FixBriefNotification>> watchNotifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  Future<void> dispose();
}

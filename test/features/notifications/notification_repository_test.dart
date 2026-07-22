import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/notifications/data/repositories/demo_notification_repository.dart';
import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 11 notification repository', () {
    test('streams role-aware notifications and persists read state', () async {
      final repository = DemoNotificationRepository(UserRole.customer);
      addTearDown(repository.dispose);

      final initial = await repository.watchNotifications().first;
      expect(initial, hasLength(4));
      expect(initial.where((item) => !item.isRead), hasLength(3));

      await repository.markRead(initial.first.id);
      expect(
        (await repository.watchNotifications().first).first.isRead,
        isTrue,
      );

      await repository.markAllRead();
      expect(
        (await repository.watchNotifications().first).every(
          (item) => item.isRead,
        ),
        isTrue,
      );
    });

    test('repairer receives matching-request updates', () async {
      final repository = DemoNotificationRepository(UserRole.repairer);
      addTearDown(repository.dispose);

      final items = await repository.watchNotifications().first;
      expect(
        items.any(
          (item) => item.type == FixBriefNotificationType.matchingRequest,
        ),
        isTrue,
      );
    });
  });

  test('notification model rejects unsafe external deep links', () {
    final notification = FixBriefNotification.fromJson({
      'id': 'notification-1',
      'notification_type': 'new_message',
      'title': 'Message',
      'body': 'Test',
      'deep_link': 'https://malicious.example/path',
      'created_at': '2026-07-22T10:00:00Z',
    });

    expect(notification.type, FixBriefNotificationType.newMessage);
    expect(notification.deepLink, isNull);
  });
}

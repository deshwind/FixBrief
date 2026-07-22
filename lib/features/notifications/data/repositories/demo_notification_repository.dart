import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';
import 'package:fixbrief/features/notifications/domain/repositories/notification_repository.dart';

class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository(UserRole role) : _items = _seed(role);

  final List<FixBriefNotification> _items;
  final StreamController<List<FixBriefNotification>> _controller =
      StreamController<List<FixBriefNotification>>.broadcast();
  bool _disposed = false;

  @override
  Stream<List<FixBriefNotification>> watchNotifications() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final index = _items.indexWhere((item) => item.id == notificationId);
    if (index < 0) {
      throw const NotificationFailure(
        'This notification is no longer available.',
      );
    }
    if (!_items[index].isRead) {
      _items[index] = _items[index].markRead();
      _emit();
    }
  }

  @override
  Future<void> markAllRead() async {
    final now = DateTime.now();
    for (var index = 0; index < _items.length; index++) {
      if (!_items[index].isRead) {
        _items[index] = _items[index].markRead(now);
      }
    }
    _emit();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _controller.close();
  }

  void _emit() {
    if (!_disposed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  static List<FixBriefNotification> _seed(UserRole role) {
    final now = DateTime.now();
    if (role == UserRole.repairer) {
      return [
        FixBriefNotification(
          id: 'demo-notification-match',
          type: FixBriefNotificationType.matchingRequest,
          title: 'New matching vehicle request',
          body: 'A Ford Focus repair in Manchester matches your services.',
          deepLink: '/repairer/requests/demo-request-vehicle',
          createdAt: now.subtract(const Duration(minutes: 12)),
        ),
        FixBriefNotification(
          id: 'demo-notification-accepted',
          type: FixBriefNotificationType.quoteAccepted,
          title: 'Your quote was accepted',
          body: 'The customer accepted your provisional estimate.',
          deepLink: '/repairer/jobs/demo-job-vehicle',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        FixBriefNotification(
          id: 'demo-notification-message-pro',
          type: FixBriefNotificationType.newMessage,
          title: 'New customer message',
          body: 'Could we confirm the inspection time?',
          deepLink: '/messages/demo-conversation-vehicle',
          readAt: now.subtract(const Duration(hours: 5)),
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      ];
    }
    return [
      FixBriefNotification(
        id: 'demo-notification-status',
        type: FixBriefNotificationType.jobStatusUpdated,
        title: 'Repair in progress',
        body: 'Northside Auto Care has started work on your Ford Focus.',
        deepLink: '/customer/jobs/demo-job-vehicle',
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      FixBriefNotification(
        id: 'demo-notification-appointment',
        type: FixBriefNotificationType.appointmentConfirmed,
        title: 'Inspection confirmed',
        body: 'Your inspection is confirmed for tomorrow at 10:30.',
        deepLink: '/messages/demo-conversation-vehicle',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      FixBriefNotification(
        id: 'demo-notification-review',
        type: FixBriefNotificationType.reviewRequested,
        title: 'How did the repair go?',
        body: 'Share feedback about your completed phone repair.',
        deepLink: '/customer/jobs/demo-job-phone/review',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      FixBriefNotification(
        id: 'demo-notification-quote',
        type: FixBriefNotificationType.newQuote,
        title: 'New provisional quote',
        body: 'A verified repair professional submitted an estimate.',
        deepLink: '/customer/requests/demo-request-vehicle/quotes',
        readAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}

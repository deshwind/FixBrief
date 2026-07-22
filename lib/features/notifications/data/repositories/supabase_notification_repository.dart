import 'dart:async';

import 'package:fixbrief/features/notifications/domain/entities/notification_models.dart';
import 'package:fixbrief/features/notifications/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<FixBriefNotification>> watchNotifications() async* {
    yield await _load();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    final changes = _client
        .from('notifications')
        .stream(primaryKey: const ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);
    await for (final _ in changes) {
      yield await _load();
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _rpc(
      'mark_notification_read',
      params: {'target_notification_id': notificationId},
    );
  }

  @override
  Future<void> markAllRead() async {
    await _rpc('mark_all_notifications_read');
  }

  @override
  Future<void> dispose() async {}

  Future<List<FixBriefNotification>> _load() async {
    final response = await _rpc('get_notifications');
    return _maps(
      response,
    ).map(FixBriefNotification.fromJson).toList(growable: false);
  }

  Future<Object?> _rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    try {
      return await _client
          .rpc<Object?>(function, params: params)
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      final missing =
          error.code == '42P01' ||
          error.code == '42883' ||
          error.code == 'PGRST202';
      throw NotificationFailure(
        missing
            ? 'The Stage 11 notifications migration has not been deployed.'
            : error.code == '42501'
            ? 'This notification is not available to your account.'
            : 'Notifications could not be updated. Check your connection and try again.',
        code: error.code,
      );
    } on TimeoutException {
      throw const NotificationFailure(
        'Notifications are taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, Object?>{};
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}

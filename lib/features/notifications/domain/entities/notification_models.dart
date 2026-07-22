import 'package:flutter/foundation.dart';

enum FixBriefNotificationType {
  newQuote,
  quoteAccepted,
  quoteRejected,
  newMessage,
  inspectionProposed,
  appointmentConfirmed,
  appointmentReminder,
  jobStatusUpdated,
  repairCompleted,
  reviewRequested,
  quoteExpiring,
  matchingRequest,
  unknown,
}

FixBriefNotificationType notificationTypeFromDatabase(Object? value) {
  return switch (value?.toString()) {
    'new_quote' => FixBriefNotificationType.newQuote,
    'quote_accepted' => FixBriefNotificationType.quoteAccepted,
    'quote_rejected' => FixBriefNotificationType.quoteRejected,
    'new_message' => FixBriefNotificationType.newMessage,
    'inspection_proposed' => FixBriefNotificationType.inspectionProposed,
    'appointment_confirmed' => FixBriefNotificationType.appointmentConfirmed,
    'appointment_reminder' => FixBriefNotificationType.appointmentReminder,
    'job_status_updated' => FixBriefNotificationType.jobStatusUpdated,
    'repair_completed' => FixBriefNotificationType.repairCompleted,
    'review_requested' => FixBriefNotificationType.reviewRequested,
    'quote_expiring' => FixBriefNotificationType.quoteExpiring,
    'matching_request' => FixBriefNotificationType.matchingRequest,
    _ => FixBriefNotificationType.unknown,
  };
}

@immutable
class FixBriefNotification {
  const FixBriefNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.relatedEntityType,
    this.relatedEntityId,
    this.deepLink,
    this.readAt,
  });

  factory FixBriefNotification.fromJson(Map<String, Object?> json) {
    return FixBriefNotification(
      id: _string(json['id']),
      type: notificationTypeFromDatabase(json['notification_type']),
      title: _string(json['title'], fallback: 'FixBrief update'),
      body: _string(json['body']),
      relatedEntityType: _nullableString(json['related_entity_type']),
      relatedEntityId: _nullableString(json['related_entity_id']),
      deepLink: _safeDeepLink(json['deep_link']),
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final FixBriefNotificationType type;
  final String title;
  final String body;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? deepLink;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  FixBriefNotification markRead([DateTime? at]) {
    return FixBriefNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      deepLink: deepLink,
      readAt: at ?? DateTime.now(),
      createdAt: createdAt,
    );
  }
}

class NotificationFailure implements Exception {
  const NotificationFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

String _string(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _safeDeepLink(Object? value) {
  final link = _nullableString(value);
  if (link == null ||
      link.length > 500 ||
      !link.startsWith('/') ||
      link.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(link);
  return uri == null || uri.hasAuthority ? null : link;
}

DateTime? _date(Object? value) {
  final text = value?.toString();
  return text == null ? null : DateTime.tryParse(text)?.toLocal();
}

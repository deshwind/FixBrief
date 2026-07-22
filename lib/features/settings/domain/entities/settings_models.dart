import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:flutter/foundation.dart';

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.newMessages = true,
    this.quoteUpdates = true,
    this.appointmentReminders = true,
    this.jobUpdates = true,
    this.matchingRequests = true,
  });

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    return NotificationPreferences(
      pushEnabled: _bool(json['push_enabled'], fallback: true),
      emailEnabled: _bool(json['email_enabled'], fallback: true),
      newMessages: _bool(json['new_messages'], fallback: true),
      quoteUpdates: _bool(json['quote_updates'], fallback: true),
      appointmentReminders: _bool(
        json['appointment_reminders'],
        fallback: true,
      ),
      jobUpdates: _bool(json['job_updates'], fallback: true),
      matchingRequests: _bool(json['matching_requests'], fallback: true),
    );
  }

  final bool pushEnabled;
  final bool emailEnabled;
  final bool newMessages;
  final bool quoteUpdates;
  final bool appointmentReminders;
  final bool jobUpdates;
  final bool matchingRequests;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? newMessages,
    bool? quoteUpdates,
    bool? appointmentReminders,
    bool? jobUpdates,
    bool? matchingRequests,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      newMessages: newMessages ?? this.newMessages,
      quoteUpdates: quoteUpdates ?? this.quoteUpdates,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      jobUpdates: jobUpdates ?? this.jobUpdates,
      matchingRequests: matchingRequests ?? this.matchingRequests,
    );
  }

  Map<String, Object?> toJson() => {
    'push_enabled': pushEnabled,
    'email_enabled': emailEnabled,
    'new_messages': newMessages,
    'quote_updates': quoteUpdates,
    'appointment_reminders': appointmentReminders,
    'job_updates': jobUpdates,
    'matching_requests': matchingRequests,
  };
}

@immutable
class DataExportRequest {
  const DataExportRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.downloadExpiresAt,
  });

  factory DataExportRequest.fromJson(Map<String, Object?> json) {
    return DataExportRequest(
      id: _string(json['id']),
      status: _string(json['status'], fallback: 'pending'),
      requestedAt: _date(json['requested_at']) ?? DateTime.now(),
      completedAt: _date(json['completed_at']),
      downloadExpiresAt: _date(json['download_expires_at']),
    );
  }

  final String id;
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final DateTime? downloadExpiresAt;
}

@immutable
class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
  });

  factory AccountDeletionRequest.fromJson(Map<String, Object?> json) {
    return AccountDeletionRequest(
      id: _string(json['id']),
      status: _string(json['status'], fallback: 'pending'),
      requestedAt: _date(json['requested_at']) ?? DateTime.now(),
      scheduledFor:
          _date(json['scheduled_for']) ??
          DateTime.now().add(const Duration(days: 14)),
    );
  }

  final String id;
  final String status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
}

@immutable
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
    this.reason,
  });

  factory BlockedUser.fromJson(Map<String, Object?> json) {
    return BlockedUser(
      userId: _string(json['user_id']),
      displayName: _string(json['display_name'], fallback: 'FixBrief member'),
      blockedAt: _date(json['blocked_at']) ?? DateTime.now(),
      reason: _nullableString(json['reason']),
    );
  }

  final String userId;
  final String displayName;
  final DateTime blockedAt;
  final String? reason;
}

@immutable
class UserSettings {
  const UserSettings({
    this.themeMode = AppThemeMode.system,
    this.effectMode = EffectMode.full,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.notifications = const NotificationPreferences(),
    this.latestExport,
    this.deletionRequest,
  });

  factory UserSettings.fromLocalJson(Map<String, Object?> json) {
    return UserSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == json['theme_mode'],
        orElse: () => AppThemeMode.system,
      ),
      effectMode: EffectMode.values.firstWhere(
        (mode) => mode.name == json['effect_mode'],
        orElse: () => EffectMode.full,
      ),
      reduceTransparency: _bool(json['reduce_transparency']),
      reduceMotion: _bool(json['reduce_motion']),
    );
  }

  final AppThemeMode themeMode;
  final EffectMode effectMode;
  final bool reduceTransparency;
  final bool reduceMotion;
  final NotificationPreferences notifications;
  final DataExportRequest? latestExport;
  final AccountDeletionRequest? deletionRequest;

  UserSettings copyWith({
    AppThemeMode? themeMode,
    EffectMode? effectMode,
    bool? reduceTransparency,
    bool? reduceMotion,
    NotificationPreferences? notifications,
    DataExportRequest? latestExport,
    AccountDeletionRequest? deletionRequest,
    bool clearDeletionRequest = false,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      effectMode: effectMode ?? this.effectMode,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      notifications: notifications ?? this.notifications,
      latestExport: latestExport ?? this.latestExport,
      deletionRequest: clearDeletionRequest
          ? null
          : deletionRequest ?? this.deletionRequest,
    );
  }

  Map<String, Object?> toLocalJson() => {
    'theme_mode': themeMode.name,
    'effect_mode': effectMode.name,
    'reduce_transparency': reduceTransparency,
    'reduce_motion': reduceMotion,
  };
}

class SettingsFailure implements Exception {
  const SettingsFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

bool _bool(Object? value, {bool fallback = false}) => switch (value) {
  final bool boolean => boolean,
  final num number => number != 0,
  final String text => text.toLowerCase() == 'true',
  _ => fallback,
};

String _string(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final text = value?.toString();
  return text == null ? null : DateTime.tryParse(text)?.toLocal();
}

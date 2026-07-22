import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:flutter/foundation.dart';

@immutable
class SettingsState {
  const SettingsState({
    this.settings = const UserSettings(),
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final UserSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? noticeMessage;

  SettingsState copyWith({
    UserSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? noticeMessage,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

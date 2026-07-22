import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/settings/data/local/settings_local_store.dart';
import 'package:fixbrief/features/settings/data/repositories/demo_settings_repository.dart';
import 'package:fixbrief/features/settings/data/repositories/supabase_settings_repository.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/domain/repositories/settings_repository.dart';
import 'package:fixbrief/features/settings/presentation/controllers/settings_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsLocalStoreProvider = Provider<SettingsLocalStore>((ref) {
  return SecureSettingsLocalStore();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  ref.watch(authSessionControllerProvider.select((state) => state.user?.id));
  final localStore = ref.watch(settingsLocalStoreProvider);
  if (ref.watch(appEnvironmentProvider).useDemoAuthentication) {
    return DemoSettingsRepository(localStore);
  }
  return SupabaseSettingsRepository(
    ref.watch(supabaseClientProvider),
    localStore,
  );
});

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((
  ref,
) {
  return ref.watch(settingsRepositoryProvider).getBlockedUsers();
});

class SettingsController extends Notifier<SettingsState> {
  late SettingsRepository _repository;

  @override
  SettingsState build() {
    _repository = ref.watch(settingsRepositoryProvider);
    unawaited(Future<void>.microtask(load));
    return const SettingsState();
  }

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final settings = await _repository.loadSettings();
      _applyAppearance(settings);
      state = state.copyWith(settings: settings, isLoading: false);
    } on SettingsFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Settings could not be loaded. Try again.',
      );
    }
  }

  void setThemeMode(AppThemeMode mode) {
    final updated = state.settings.copyWith(themeMode: mode);
    state = state.copyWith(settings: updated, clearError: true);
    ref.read(appThemeModeProvider.notifier).setMode(mode);
    unawaited(_saveAppearance(updated));
  }

  void setEffectMode(EffectMode mode) {
    final updated = state.settings.copyWith(effectMode: mode);
    state = state.copyWith(settings: updated, clearError: true);
    ref.read(accessibilityEffectsControllerProvider.notifier).setMode(mode);
    unawaited(_saveAppearance(updated));
  }

  void setReduceTransparency(bool value) {
    final updated = state.settings.copyWith(reduceTransparency: value);
    state = state.copyWith(settings: updated, clearError: true);
    ref
        .read(accessibilityEffectsControllerProvider.notifier)
        .setReduceTransparency(value);
    unawaited(_saveAppearance(updated));
  }

  void setReduceMotion(bool value) {
    final updated = state.settings.copyWith(reduceMotion: value);
    state = state.copyWith(settings: updated, clearError: true);
    ref
        .read(accessibilityEffectsControllerProvider.notifier)
        .setReduceMotion(value);
    unawaited(_saveAppearance(updated));
  }

  Future<void> updateNotifications(NotificationPreferences preferences) async {
    state = state.copyWith(
      settings: state.settings.copyWith(notifications: preferences),
      isSaving: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final saved = await _repository.updateNotificationPreferences(
        preferences,
      );
      state = state.copyWith(
        settings: state.settings.copyWith(notifications: saved),
        isSaving: false,
        noticeMessage: 'Notification preferences saved.',
      );
    } on SettingsFailure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Notification preferences could not be saved.',
      );
    }
  }

  Future<void> requestDataExport() async {
    state = state.copyWith(isSaving: true, clearError: true, clearNotice: true);
    try {
      final request = await _repository.requestDataExport();
      state = state.copyWith(
        settings: state.settings.copyWith(latestExport: request),
        isSaving: false,
        noticeMessage: 'Your data export has been requested.',
      );
    } on SettingsFailure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'The data export could not be requested.',
      );
    }
  }

  Future<bool> requestAccountDeletion({String? reason}) async {
    state = state.copyWith(isSaving: true, clearError: true, clearNotice: true);
    try {
      final request = await _repository.requestAccountDeletion(reason: reason);
      state = state.copyWith(
        settings: state.settings.copyWith(deletionRequest: request),
        isSaving: false,
        noticeMessage: 'Account deletion has been scheduled.',
      );
      return true;
    } on SettingsFailure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Account deletion could not be scheduled.',
      );
      return false;
    }
  }

  Future<void> cancelAccountDeletion() async {
    state = state.copyWith(isSaving: true, clearError: true, clearNotice: true);
    try {
      await _repository.cancelAccountDeletion();
      state = state.copyWith(
        settings: state.settings.copyWith(clearDeletionRequest: true),
        isSaving: false,
        noticeMessage: 'Account deletion has been cancelled.',
      );
    } on SettingsFailure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Account deletion could not be cancelled.',
      );
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }

  Future<void> _saveAppearance(UserSettings settings) async {
    try {
      await _repository.saveAppearance(settings);
    } on Object {
      state = state.copyWith(
        errorMessage: 'Appearance preferences could not be saved.',
      );
    }
  }

  void _applyAppearance(UserSettings settings) {
    ref.read(appThemeModeProvider.notifier).setMode(settings.themeMode);
    final effects = ref.read(accessibilityEffectsControllerProvider.notifier);
    effects
      ..setMode(settings.effectMode)
      ..setReduceTransparency(settings.reduceTransparency)
      ..setReduceMotion(settings.reduceMotion);
  }
}

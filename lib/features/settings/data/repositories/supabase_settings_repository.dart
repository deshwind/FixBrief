import 'dart:async';

import 'package:fixbrief/features/settings/data/local/settings_local_store.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/domain/repositories/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(this._client, this._localStore);

  final SupabaseClient _client;
  final SettingsLocalStore _localStore;

  @override
  Future<UserSettings> loadSettings() async {
    final local = await _localStore.read();
    if (_client.auth.currentUser == null) {
      return local;
    }
    final response = _map(await _rpc('get_settings_overview'));
    final preferences = _map(response['preferences']);
    final export = _map(response['latest_export']);
    final deletion = _map(response['deletion_request']);
    return local.copyWith(
      notifications: NotificationPreferences.fromJson(preferences),
      latestExport: export.isEmpty ? null : DataExportRequest.fromJson(export),
      deletionRequest: deletion.isEmpty
          ? null
          : AccountDeletionRequest.fromJson(deletion),
    );
  }

  @override
  Future<void> saveAppearance(UserSettings settings) {
    return _localStore.write(settings);
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final response = await _rpc(
      'update_notification_preferences',
      params: {'preferences': preferences.toJson()},
    );
    return NotificationPreferences.fromJson(_map(response));
  }

  @override
  Future<DataExportRequest> requestDataExport() async {
    final response = await _rpc('request_data_export');
    return DataExportRequest.fromJson(_map(response));
  }

  @override
  Future<AccountDeletionRequest> requestAccountDeletion({
    String? reason,
  }) async {
    final response = await _rpc(
      'request_account_deletion',
      params: {'confirmation': 'DELETE', 'reason': reason?.trim()},
    );
    return AccountDeletionRequest.fromJson(_map(response));
  }

  @override
  Future<void> cancelAccountDeletion() async {
    await _rpc('cancel_account_deletion');
  }

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _rpc('get_blocked_users');
    return _maps(response).map(BlockedUser.fromJson).toList(growable: false);
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _rpc('unblock_user', params: {'target_user_id': userId});
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
      throw _mapFailure(error);
    } on TimeoutException {
      throw const SettingsFailure(
        'Settings are taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  SettingsFailure _mapFailure(PostgrestException error) {
    final missing =
        error.code == '42P01' ||
        error.code == '42883' ||
        error.code == 'PGRST202';
    return SettingsFailure(
      missing
          ? 'The Stage 11 settings migration has not been deployed.'
          : error.code == '42501'
          ? 'This account setting is not available to your account.'
          : error.code == '22023' || error.code == '23514'
          ? error.message
          : 'Settings could not be updated. Check your connection and try again.',
      code: error.code,
    );
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

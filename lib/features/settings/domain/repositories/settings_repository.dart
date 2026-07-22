import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';

abstract interface class SettingsRepository {
  Future<UserSettings> loadSettings();

  Future<void> saveAppearance(UserSettings settings);

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  Future<DataExportRequest> requestDataExport();

  Future<AccountDeletionRequest> requestAccountDeletion({String? reason});

  Future<void> cancelAccountDeletion();

  Future<List<BlockedUser>> getBlockedUsers();

  Future<void> unblockUser(String userId);
}

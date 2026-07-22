import 'package:fixbrief/features/settings/data/local/settings_local_store.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/domain/repositories/settings_repository.dart';
import 'package:uuid/uuid.dart';

class DemoSettingsRepository implements SettingsRepository {
  DemoSettingsRepository(this._localStore);

  final SettingsLocalStore _localStore;
  final Uuid _uuid = const Uuid();
  NotificationPreferences _notifications = const NotificationPreferences();
  DataExportRequest? _latestExport;
  AccountDeletionRequest? _deletionRequest;
  final List<BlockedUser> _blockedUsers = [
    BlockedUser(
      userId: 'demo-blocked-user',
      displayName: 'Example blocked member',
      reason: 'Blocked from a conversation',
      blockedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<UserSettings> loadSettings() async {
    final local = await _localStore.read();
    return local.copyWith(
      notifications: _notifications,
      latestExport: _latestExport,
      deletionRequest: _deletionRequest,
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
    _notifications = preferences;
    return _notifications;
  }

  @override
  Future<DataExportRequest> requestDataExport() async {
    return _latestExport ??= DataExportRequest(
      id: 'demo-export-${_uuid.v4()}',
      status: 'pending',
      requestedAt: DateTime.now(),
    );
  }

  @override
  Future<AccountDeletionRequest> requestAccountDeletion({
    String? reason,
  }) async {
    return _deletionRequest ??= AccountDeletionRequest(
      id: 'demo-deletion-${_uuid.v4()}',
      status: 'pending',
      requestedAt: DateTime.now(),
      scheduledFor: DateTime.now().add(const Duration(days: 14)),
    );
  }

  @override
  Future<void> cancelAccountDeletion() async {
    _deletionRequest = null;
  }

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    return List.unmodifiable(_blockedUsers);
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blockedUsers.removeWhere((user) => user.userId == userId);
  }
}

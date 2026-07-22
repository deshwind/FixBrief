import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:fixbrief/features/settings/data/local/settings_local_store.dart';
import 'package:fixbrief/features/settings/data/repositories/demo_settings_repository.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 11 settings repository', () {
    late _MemorySettingsLocalStore localStore;
    late DemoSettingsRepository repository;

    setUp(() {
      localStore = _MemorySettingsLocalStore();
      repository = DemoSettingsRepository(localStore);
    });

    test('persists appearance and notification preferences', () async {
      final initial = await repository.loadSettings();
      expect(initial.themeMode, AppThemeMode.system);

      final dark = initial.copyWith(
        themeMode: AppThemeMode.dark,
        reduceMotion: true,
      );
      await repository.saveAppearance(dark);
      final preferences = await repository.updateNotificationPreferences(
        initial.notifications.copyWith(pushEnabled: false, quoteUpdates: false),
      );

      final loaded = await repository.loadSettings();
      expect(loaded.themeMode, AppThemeMode.dark);
      expect(loaded.reduceMotion, isTrue);
      expect(preferences.pushEnabled, isFalse);
      expect(loaded.notifications.quoteUpdates, isFalse);
    });

    test(
      'privacy requests are idempotent and deletion can be cancelled',
      () async {
        final firstExport = await repository.requestDataExport();
        final secondExport = await repository.requestDataExport();
        expect(secondExport.id, firstExport.id);

        final deletion = await repository.requestAccountDeletion(
          reason: 'No longer needed',
        );
        expect(deletion.status, 'pending');
        expect(deletion.scheduledFor.isAfter(DateTime.now()), isTrue);

        await repository.cancelAccountDeletion();
        expect((await repository.loadSettings()).deletionRequest, isNull);
      },
    );

    test('blocked members can be reviewed and unblocked', () async {
      final users = await repository.getBlockedUsers();
      expect(users, hasLength(1));

      await repository.unblockUser(users.single.userId);
      expect(await repository.getBlockedUsers(), isEmpty);
    });
  });
}

class _MemorySettingsLocalStore implements SettingsLocalStore {
  UserSettings settings = const UserSettings();

  @override
  Future<UserSettings> read() async => settings;

  @override
  Future<void> write(UserSettings settings) async {
    this.settings = settings;
  }
}

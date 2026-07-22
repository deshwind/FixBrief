import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/notifications/data/repositories/demo_notification_repository.dart';
import 'package:fixbrief/features/notifications/presentation/providers/notification_providers.dart';
import 'package:fixbrief/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:fixbrief/features/settings/data/local/settings_local_store.dart';
import 'package:fixbrief/features/settings/data/repositories/demo_settings_repository.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/presentation/providers/settings_providers.dart';
import 'package:fixbrief/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const environment = AppEnvironment(
    flavor: AppFlavor.development,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'test-anon-key',
    useDemoAuthentication: true,
  );

  testWidgets('notification inbox shows unread job and appointment updates', (
    tester,
  ) async {
    _setPhone(tester);
    final notifications = DemoNotificationRepository(UserRole.customer);
    addTearDown(notifications.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          notificationRepositoryProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Repair in progress'));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Inspection confirmed'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('settings exposes appearance, accessibility and notifications', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoSettingsRepository(_MemorySettingsLocalStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Appearance'));

    expect(find.text('Reduce transparency'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Push notifications'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Push notifications'), findsOneWidget);
    expect(find.text('Quote updates'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Request a data export'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Request a data export'), findsOneWidget);
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

void _setPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

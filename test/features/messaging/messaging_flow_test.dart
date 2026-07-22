import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/messaging/data/repositories/demo_messaging_repository.dart';
import 'package:fixbrief/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:fixbrief/features/messaging/presentation/screens/conversation_screen.dart';
import 'package:fixbrief/features/messaging/presentation/screens/conversations_screen.dart';
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

  testWidgets('conversation inbox shows authorized repair contact', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoMessagingRepository(
      'customer-user',
      UserRole.customer,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          messagingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: const ConversationsScreen(),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Northside Auto Care'));

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('2018 Ford Focus · Manchester M20'), findsOneWidget);
    expect(find.textContaining('inspect the clicking noise'), findsOneWidget);
  });

  testWidgets('conversation shows messages, composer and appointment control', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoMessagingRepository(
      'customer-user',
      UserRole.customer,
    );
    addTearDown(repository.dispose);
    final conversation = (await repository.watchConversations().first).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          messagingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: ConversationScreen(
            conversationId: conversation.id,
            initialConversation: conversation,
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      find.text('The clicking is louder on full-lock turns.'),
    );

    expect(find.text('Message securely'), findsOneWidget);
    expect(find.byTooltip('Attach evidence or document'), findsOneWidget);
    expect(find.byTooltip('Suggest appointment'), findsOneWidget);
    expect(find.byTooltip('Conversation actions'), findsOneWidget);
  });

  testWidgets('report dialog submits without a lifecycle exception', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoMessagingRepository(
      'customer-user',
      UserRole.customer,
    );
    addTearDown(repository.dispose);
    final conversation = (await repository.watchConversations().first).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          messagingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: ConversationScreen(
            conversationId: conversation.id,
            initialConversation: conversation,
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      find.text('The clicking is louder on full-lock turns.'),
    );

    await tester.tap(find.byTooltip('Conversation actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.ancestor(
        of: find.text('Report member'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, 'Details (optional)'),
      'Automated report lifecycle test',
    );
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Report submitted for review.'), findsOneWidget);
  });
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

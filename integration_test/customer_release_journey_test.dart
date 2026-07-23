import 'package:fixbrief/app/app.dart';
import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const environment = AppEnvironment(
    flavor: AppFlavor.development,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'stage-12-integration-key',
    useDemoAuthentication: true,
  );

  testWidgets('customer completes the release-critical account journey', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
        child: const FixBriefApp(environment: environment),
      ),
    );
    await _waitFor(tester, find.text('Repairs start with a clearer brief.'));

    await _scrollToAndTap(tester, find.text('Sign in'));
    await _waitFor(tester, find.text('Welcome back'));

    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), 'release@example.com');
    await tester.enterText(loginFields.at(1), 'FixBriefDemo123');
    await _scrollToAndTap(tester, find.text('Sign in'));
    await _waitFor(tester, find.text('How will you use FixBrief?'));

    await tester.tap(find.text('I need something repaired'));
    await _waitFor(tester, find.text('Complete your customer profile'));

    final onboardingFields = find.byType(TextFormField);
    await tester.enterText(onboardingFields.at(0), 'Release Tester');
    await tester.enterText(onboardingFields.at(1), '+44 7700 900000');
    await tester.enterText(onboardingFields.at(2), 'Manchester M20');
    await _scrollToAndTap(tester, find.text('Finish customer setup'));
    await _waitFor(tester, find.text('Start a new repair request'));

    await tester.tap(find.byTooltip('3 unread notifications'));
    await _waitFor(tester, find.text('Repair in progress'));
    expect(find.text('Inspection confirmed'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Unread'), findsNothing);

    await tester.tap(find.byTooltip('Notification settings'));
    await _waitFor(tester, find.text('Appearance'));
    expect(find.text('Reduce motion'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('Request a data export'));
    await _waitFor(tester, find.text('Your data export has been requested.'));
    expect(find.textContaining('Latest request: pending'), findsOneWidget);
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      continue;
    }
    await tester.drag(
      scrollables.last,
      const Offset(0, -250),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 200));
  final inkWell = find.ancestor(of: target, matching: find.byType(InkWell));
  await tester.tap(
    inkWell.evaluate().isEmpty ? target.first : inkWell.first,
    warnIfMissed: false,
  );
}

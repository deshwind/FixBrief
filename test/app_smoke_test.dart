import 'package:fixbrief/app/app.dart';
import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
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

  testWidgets('customer can complete the Stage 3 account journey', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
        child: const FixBriefApp(environment: environment),
      ),
    );
    await _advance(tester);

    expect(find.text('Repairs start with a clearer brief.'), findsOneWidget);

    final createAccountButton = find.text('Create an account');
    await _scrollToAndTap(tester, createAccountButton);
    await _advance(tester);

    final registrationFields = find.byType(TextFormField);
    await tester.enterText(registrationFields.at(0), 'alex@example.com');
    await tester.enterText(registrationFields.at(1), 'FixBriefDemo123');
    await tester.enterText(registrationFields.at(2), 'FixBriefDemo123');
    await tester.tap(find.byType(Checkbox));
    await _scrollToAndTap(tester, find.text('Create account'));
    await _advance(tester);

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('alex@example.com'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('I have verified my email'));
    await _advance(tester);

    expect(find.text('How will you use FixBrief?'), findsOneWidget);
    await tester.tap(find.text('I need something repaired'));
    await _advance(tester);

    expect(find.text('Complete your customer profile'), findsOneWidget);
    final onboardingFields = find.byType(TextFormField);
    await tester.enterText(onboardingFields.at(0), 'Alex Morgan');
    await tester.enterText(onboardingFields.at(1), '+44 7700 900000');
    await tester.enterText(onboardingFields.at(2), 'Manchester M20');
    await _scrollToAndTap(tester, find.text('Finish customer setup'));
    await _advance(tester);

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Start a new repair request'), findsOneWidget);

    await tester.tap(find.byTooltip('Open AI assessment'));
    await _pumpUntil(tester, find.text('Problem summary'));
    expect(find.text('AI-assisted assessment'), findsOneWidget);
    expect(
      find.text('AI-assisted assessment — not a confirmed diagnosis.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('repairer account is routed to business onboarding', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
        child: const FixBriefApp(environment: environment),
      ),
    );
    await _advance(tester);

    final welcomeSignInButton = find.text('Sign in');
    await _scrollToAndTap(tester, welcomeSignInButton);
    await _advance(tester);
    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), 'sam@northline.example');
    await tester.enterText(loginFields.at(1), 'FixBriefDemo123');
    final loginButton = find.text('Sign in');
    await _scrollToAndTap(tester, loginButton);
    await _advance(tester);

    expect(find.text('How will you use FixBrief?'), findsOneWidget);
    await tester.tap(find.text('I am a repair professional'));
    await _advance(tester);

    expect(find.text('Build your repair business profile'), findsOneWidget);
    expect(find.text('Business identity'), findsOneWidget);
    expect(find.text('Repair categories'), findsOneWidget);
    expect(find.text('Service and availability'), findsOneWidget);
    expect(find.text('Submit business profile'), findsOneWidget);
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
  final inkWell = find.ancestor(of: target, matching: find.byType(InkWell));
  await tester.tap(inkWell.evaluate().isEmpty ? target : inkWell.first);
}

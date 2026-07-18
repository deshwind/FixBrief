import 'package:drift/native.dart';
import 'package:fixbrief/app/app.dart';
import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/features/repair_requests/data/local/repair_draft_database.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
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

  testWidgets('customer completes the request and AI assessment journey', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = RepairDraftDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        repairDraftDatabaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FixBriefApp(environment: environment),
      ),
    );
    await _advance(tester);
    await _createCustomer(tester);

    await _scrollToAndTap(tester, find.text('Start a new repair request'));
    await _advance(tester);
    expect(find.text('Choose the closest category'), findsOneWidget);

    await _scrollToAndTap(tester, find.byKey(const Key('category-appliances')));
    await _tapNext(tester);
    expect(find.text('Identify the item'), findsOneWidget);

    await _enterDraftText(tester, const Key('item-name'), 'Washing machine');
    await _tapNext(tester);
    expect(find.text('Describe it in your own words'), findsOneWidget);

    await _enterDraftText(
      tester,
      const Key('problem-description'),
      'It makes a loud knocking sound throughout the spin cycle.',
    );
    await _tapNext(tester);
    expect(find.text('Show repairers what you can'), findsOneWidget);

    await _tapNext(tester);
    expect(find.text('Your repair brief'), findsOneWidget);

    await _scrollToAndTap(tester, find.text('Add availability'));
    await _advance(tester);
    expect(find.text('When and where?'), findsOneWidget);

    await _enterDraftText(
      tester,
      const Key('approximate-area'),
      'Manchester M20',
    );
    await _enterDraftText(
      tester,
      const Key('exact-address'),
      '10 Example Street, Manchester',
    );
    await _scrollToAndTap(tester, find.text('Submit for assessment'));
    await _pumpUntil(tester, find.text('Repair request submitted'));

    expect(find.text('Repair request submitted'), findsOneWidget);
    expect(find.textContaining('awaiting assessment'), findsOneWidget);

    final submittedId = container
        .read(repairRequestWizardControllerProvider)
        .draft
        ?.id;
    await _scrollToAndTap(tester, find.text('Start AI assessment'));
    await _pumpUntil(tester, find.text('Problem summary'));

    expect(find.text('Possible causes may include'), findsOneWidget);
    expect(
      find.text('AI-assisted assessment — not a confirmed diagnosis.'),
      findsOneWidget,
    );

    await _scrollToAndTap(tester, find.text('Answer follow-up questions'));
    await _advance(tester);
    final answerFields = find.byType(TextFormField);
    await tester.enterText(answerFields.first, 'It happens with every load.');
    await _scrollToAndTap(tester, find.text('Skip this question'));
    await _scrollToAndTap(tester, find.text('Update assessment'));
    await _pumpUntil(
      tester,
      find.text('Your answers have been added to the repair brief.'),
    );

    await _scrollToAndTap(tester, find.text('Review repair brief'));
    await _advance(tester);
    expect(find.text('Review your repair brief'), findsOneWidget);
    await _scrollToAndTap(tester, find.text('Approve and publish request'));
    await _pumpUntil(tester, find.text('Repair request published'));

    expect(find.text('Repair request published'), findsOneWidget);
    await _scrollToAndTap(tester, find.text('Return home'));
    await _advance(tester);
    await _scrollToAndTap(tester, find.text('Start a new repair request'));
    await _advance(tester);

    final nextDraft = container
        .read(repairRequestWizardControllerProvider)
        .draft;
    expect(find.text('Choose the closest category'), findsOneWidget);
    expect(nextDraft?.id, isNot(submittedId));
    expect(nextDraft?.categorySlug, isNull);
  });
}

Future<void> _createCustomer(WidgetTester tester) async {
  await _scrollToAndTap(tester, find.text('Create an account'));
  await _advance(tester);
  final registrationFields = find.byType(TextFormField);
  await tester.enterText(registrationFields.at(0), 'stage5@example.com');
  await tester.enterText(registrationFields.at(1), 'FixBriefDemo123');
  await tester.enterText(registrationFields.at(2), 'FixBriefDemo123');
  await tester.tap(find.byType(Checkbox));
  await _scrollToAndTap(tester, find.text('Create account'));
  await _advance(tester);
  await _scrollToAndTap(tester, find.text('I have verified my email'));
  await _advance(tester);
  await tester.tap(find.text('I need something repaired'));
  await _advance(tester);
  final onboardingFields = find.byType(TextFormField);
  await tester.enterText(onboardingFields.at(0), 'Alex Morgan');
  await tester.enterText(onboardingFields.at(1), '+44 7700 900000');
  await tester.enterText(onboardingFields.at(2), 'Manchester M20');
  await _scrollToAndTap(tester, find.text('Finish customer setup'));
  await _advance(tester);
}

Future<void> _enterDraftText(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('repair-wizard-next')));
  await _advance(tester);
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
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
  await tester.pump(const Duration(milliseconds: 250));
  final inkWell = find.ancestor(of: target, matching: find.byType(InkWell));
  await tester.tap(inkWell.evaluate().isEmpty ? target : inkWell.first);
}

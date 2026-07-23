import 'package:fixbrief/app/app.dart';
import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const environment = AppEnvironment(
    flavor: AppFlavor.development,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'full-journey-integration-key',
    useDemoAuthentication: true,
  );

  testWidgets(
    'customer completes account, brief, AI, quote, settings, job and message',
    (tester) async {
      await _launch(tester, environment);
      await _registerCustomer(tester);
      await _publishRepairRequest(tester);

      await _tap(tester, find.text('Ford Focus clicking noise'));
      await _waitFor(tester, find.text('Compare quotes'));
      await _tap(tester, find.text('Accept quote').first);
      await _waitFor(tester, find.text('Keep comparing'));
      await _tap(tester, find.text('Accept quote').last);
      await _waitFor(
        tester,
        find.text('Quote accepted. Your repair job has been created.'),
      );

      await _tapTooltipControl(tester, 'Back home');
      await _waitFor(tester, find.text('Start a new repair request'));
      await _waitForTransientNotice(tester);

      await _tapNavigation(tester, 'Profile');
      await _waitFor(tester, find.text('Customer account'));
      await _tap(tester, find.text('Settings and accessibility'));
      await _waitFor(tester, find.text('Appearance'));
      await _tap(tester, find.text('Reduce motion'));
      await _tap(tester, find.text('Request a data export'));
      await _waitFor(tester, find.text('Your data export has been requested.'));
      await _waitForTransientNotice(tester);

      await _tap(tester, find.text('Privacy policy'));
      await _waitFor(tester, find.text('Information we use'));
      await tester.pageBack();
      await _pump(tester);
      await _tap(tester, find.text('Terms and conditions'));
      await _waitFor(tester, find.text('Marketplace role'));
      await tester.pageBack();
      await _pump(tester);
      await tester.pageBack();
      await _pump(tester);

      await _tap(tester, find.text('Help and support'));
      await _waitFor(tester, find.text('Immediate safety concern?'));
      await _tap(tester, find.text('Is the AI assessment a diagnosis?'));
      await _waitFor(
        tester,
        find.textContaining('A qualified professional must inspect'),
      );
      await tester.pageBack();
      await _pump(tester);
      await _tapTooltipControl(tester, 'Customer home');
      await _waitFor(tester, find.text('Start a new repair request'));

      await _tapNavigation(tester, 'Requests');
      await _waitFor(tester, find.text('My repairs'));
      await _tap(tester, find.text('2018 Ford Focus'));
      await _waitFor(tester, find.text('Repair timeline'));
      await _tap(tester, find.text('Confirm repair completed'));
      await _waitFor(tester, find.text('Confirm update'));
      await _tap(tester, find.text('Confirm update'));
      await _waitFor(tester, find.text('Review repair professional'));
      await _waitForTransientNotice(tester);
      await _tap(tester, find.text('Review repair professional'));
      await _waitFor(tester, find.text('Overall experience'));

      for (final category in const [
        'Overall experience',
        'Quality of repair',
        'Communication',
        'Punctuality',
        'Value for money',
        'Quote accuracy',
      ]) {
        await _rateFiveStars(tester, category);
      }
      await _enterText(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Written feedback (optional)',
        ),
        'Clear communication and a well explained repair.',
      );
      await _tap(tester, find.text('Publish review'));
      await _waitFor(tester, find.text('Reviews'));
      await _waitForTransientNotice(tester);

      await _tap(tester, find.text('Message repair professional'));
      await _waitFor(tester, find.text('Northside Auto Care'));
      await _tap(tester, find.text('Northside Auto Care'));
      await _waitFor(tester, find.text('Message securely'));
      const message = 'The repaired item is working well. Thank you.';
      await _enterText(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Message securely',
        ),
        message,
      );
      await _tapTooltipControl(tester, 'Send message');
      await _waitFor(tester, find.text(message));

      await _tapTooltipControl(tester, 'Suggest appointment');
      await _waitFor(tester, find.text('Suggest an appointment'));
      await _tap(tester, find.text('Send proposal'));
      await _waitFor(tester, find.text('Appointment proposal sent.'));
    },
  );

  testWidgets(
    'repairer completes onboarding, discovery, quote and job management',
    (tester) async {
      await _launch(tester, environment);
      await _signInRepairer(tester);

      await _tapNavigation(tester, 'Requests');
      await _waitFor(tester, find.text('Matching requests'));
      await _tap(tester, find.text('Ford Focus'));
      await _waitFor(tester, find.text('Customer-approved repair brief'));
      expect(find.text('Privacy-safe marketplace view'), findsOneWidget);
      expect(
        find.text('AI-assisted assessment — not a confirmed diagnosis.'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Prepare or edit provisional quote'));
      await _waitFor(tester, find.text('Prepare a quote'));
      await _tap(tester, find.text('Submit provisional quote'));
      await _waitFor(
        tester,
        find.text(
          'Provisional quote submitted. The customer can now compare it.',
        ),
      );
      await _tapTooltipControl(tester, 'Back to request');
      await _waitFor(tester, find.text('Customer-approved repair brief'));
      await _tapTooltipControl(tester, 'Back to matching requests');
      await _waitFor(tester, find.text('Matching requests'));
      await _waitForTransientNotice(tester);

      await _tapNavigation(tester, 'Jobs');
      await _waitFor(tester, find.text('Jobs'));
      expect(find.text('Active jobs'), findsOneWidget);
      await _tapTooltipControl(tester, 'My quotes');
      await _waitFor(tester, find.text('Your quotes'));
      expect(find.text('Submitted'), findsWidgets);

      await _tapNavigation(tester, 'Messages');
      await _waitFor(tester, find.text('Messages'));
      expect(find.text('Alex Morgan'), findsOneWidget);

      await _tapNavigation(tester, 'Profile');
      await _waitFor(tester, find.text('Repair professional account'));
      await _tapTooltipControl(tester, 'Dashboard');
      await _waitFor(tester, find.text('New matching requests'));

      await _tapNavigation(tester, 'Jobs');
      await _waitFor(tester, find.text('Active jobs'));
      await _tap(tester, find.text('2018 Ford Focus'));
      await _waitFor(tester, find.text('Repair timeline'));
      await _tap(tester, find.text('Mark ready for collection'));
      await _waitFor(tester, find.text('Confirm update'));
      await _tap(tester, find.text('Confirm update'));
      await _waitFor(tester, find.text('Ready for collection'));
    },
  );
}

Future<void> _launch(WidgetTester tester, AppEnvironment environment) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: FixBriefApp(environment: environment),
    ),
  );
  await _waitFor(tester, find.text('Repairs start with a clearer brief.'));
}

Future<void> _registerCustomer(WidgetTester tester) async {
  await _tap(tester, find.text('Create an account'));
  await _waitFor(tester, find.text('Create your account'));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'full.customer@example.com');
  await tester.enterText(fields.at(1), 'FixBriefDemo123');
  await tester.enterText(fields.at(2), 'FixBriefDemo123');
  await _tap(tester, find.byType(Checkbox));
  await _tap(tester, find.text('Create account'));
  await _waitFor(tester, find.text('Verify your email'));
  await _tap(tester, find.text('I have verified my email'));
  await _waitFor(tester, find.text('How will you use FixBrief?'));
  await _tap(tester, find.text('I need something repaired'));
  await _waitFor(tester, find.text('Complete your customer profile'));

  final onboarding = find.byType(TextFormField);
  await tester.enterText(onboarding.at(0), 'Full Journey Customer');
  await tester.enterText(onboarding.at(1), '+44 7700 900111');
  await tester.enterText(onboarding.at(2), 'Manchester M20');
  await _tap(tester, find.text('Finish customer setup'));
  await _waitFor(tester, find.text('Start a new repair request'));
}

Future<void> _publishRepairRequest(WidgetTester tester) async {
  await _tap(tester, find.text('Start a new repair request'));
  await _waitFor(tester, find.text('Choose the closest category'));
  await _tap(tester, find.byKey(const Key('category-appliances')));
  await _tap(tester, find.byKey(const Key('repair-wizard-next')));

  await _waitFor(tester, find.text('Identify the item'));
  await _enterDraftText(tester, const Key('item-name'), 'Washing machine');
  await _tap(tester, find.byKey(const Key('repair-wizard-next')));

  await _waitFor(tester, find.text('Describe it in your own words'));
  await _enterDraftText(
    tester,
    const Key('problem-description'),
    'It makes a loud knocking sound throughout every spin cycle.',
  );
  await _tap(tester, find.byKey(const Key('repair-wizard-next')));

  await _waitFor(tester, find.text('Show repairers what you can'));
  await _tap(tester, find.byKey(const Key('repair-wizard-next')));
  await _waitFor(tester, find.text('Your repair brief'));
  await _tap(tester, find.text('Add availability'));

  await _waitFor(tester, find.text('When and where?'));
  await _enterDraftText(
    tester,
    const Key('approximate-area'),
    'Manchester M20',
  );
  await _enterDraftText(
    tester,
    const Key('exact-address'),
    '10 Integration Street, Manchester',
  );
  await _tap(tester, find.text('Submit for assessment'));

  await _waitFor(tester, find.text('Repair request submitted'));
  await _tap(tester, find.text('Start AI assessment'));
  await _waitFor(tester, find.text('Problem summary'));
  expect(
    find.text('AI-assisted assessment — not a confirmed diagnosis.'),
    findsOneWidget,
  );

  await _tap(tester, find.text('Answer follow-up questions'));
  await _waitFor(tester, find.byType(TextFormField));
  await tester.enterText(
    find.byType(TextFormField).first,
    'The sound occurs with every load.',
  );
  await _tap(tester, find.text('Skip this question'));
  await _tap(tester, find.text('Update assessment'));
  await _waitFor(
    tester,
    find.text('Your answers have been added to the repair brief.'),
  );
  await _tap(tester, find.text('Review repair brief'));
  await _waitFor(tester, find.text('Review your repair brief'));
  await _tap(tester, find.text('Approve and publish request'));
  await _waitFor(tester, find.text('Repair request published'));
  await _tap(tester, find.text('Return home'));
  await _waitFor(tester, find.text('Start a new repair request'));
}

Future<void> _signInRepairer(WidgetTester tester) async {
  await _tap(tester, find.text('Sign in'));
  await _waitFor(tester, find.text('Welcome back'));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'full.repairer@example.com');
  await tester.enterText(fields.at(1), 'FixBriefDemo123');
  await _tap(tester, find.text('Sign in'));
  await _waitFor(tester, find.text('How will you use FixBrief?'));
  await _tap(tester, find.text('I am a repair professional'));
  await _waitFor(tester, find.text('Build your repair business profile'));

  final onboarding = find.byType(TextFormField);
  final values = [
    'Sam North',
    'Northline Repairs',
    '+44 7700 900222',
    'sam@northline.example',
    'Mobile vehicle diagnostics and mechanical repairs.',
    '12',
    'Vehicle diagnostics, steering, suspension',
    'Level 3 Vehicle Maintenance',
    'ATA accredited',
    '45',
    '35',
    '1 Workshop Road, Manchester',
    'Mon-Fri 08:00-17:30',
  ];
  expect(onboarding, findsNWidgets(values.length));
  for (var index = 0; index < values.length; index++) {
    await tester.enterText(onboarding.at(index), values[index]);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await _pump(tester);
  final carsChip = find.widgetWithText(LiquidGlassChip, 'Cars');
  final carsInkWell = find.descendant(
    of: carsChip,
    matching: find.byType(InkWell),
  );
  await _tap(tester, carsInkWell);
  expect(tester.widget<LiquidGlassChip>(carsChip).selected, isTrue);
  await _tap(tester, find.text('Submit business profile'));
  await _waitFor(tester, find.text('New matching requests'), attempts: 200);
}

Future<void> _enterDraftText(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
  await _enterText(tester, field, text);
}

Future<void> _rateFiveStars(WidgetTester tester, String category) async {
  final rating = find.bySemanticsLabel('$category: 5 out of 5 stars');
  await _scrollUntilFound(tester, rating);
  await _tap(tester, rating);
}

Future<void> _enterText(WidgetTester tester, Finder field, String text) async {
  await _scrollUntilFound(tester, field);
  await tester.ensureVisible(field.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(field.first, text);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _scrollUntilFound(tester, target);
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 250));
  final visible = target.hitTestable();
  await tester.tap(
    visible.evaluate().isEmpty ? target.first : visible.first,
    warnIfMissed: false,
  );
  await _pump(tester);
}

Future<void> _tapNavigation(WidgetTester tester, String label) async {
  final navigation = find.byType(LiquidGlassNavigationBar);
  await _waitFor(tester, navigation);
  final target = find.descendant(of: navigation, matching: find.text(label));
  await _scrollUntilFound(tester, target);
  final inkWell = find.ancestor(of: target, matching: find.byType(InkWell));
  expect(inkWell, findsWidgets);
  await tester.ensureVisible(inkWell.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(inkWell.first);
  await _pump(tester);
}

Future<void> _tapTooltipControl(WidgetTester tester, String label) async {
  final tooltip = find.byTooltip(label);
  await _scrollUntilFound(tester, tooltip);
  final iconButton = find.ancestor(
    of: tooltip,
    matching: find.byType(IconButton),
  );
  if (iconButton.evaluate().isNotEmpty) {
    await _tap(tester, iconButton.first);
    return;
  }
  final inkWell = find.descendant(of: tooltip, matching: find.byType(InkWell));
  expect(inkWell, findsWidgets);
  await _tap(tester, inkWell.first);
}

Future<void> _scrollUntilFound(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      continue;
    }
    await tester.drag(
      scrollables.last,
      const Offset(0, -300),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
  for (var attempt = 0; attempt < 30 && target.evaluate().isEmpty; attempt++) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      continue;
    }
    await tester.drag(
      scrollables.last,
      const Offset(0, 300),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
  if (target.evaluate().isEmpty) {
    final currentText = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    debugPrint('Scroll search screen text: $currentText');
  }
  expect(target, findsWidgets);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (
    var attempt = 0;
    attempt < attempts && finder.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (finder.evaluate().isEmpty) {
    final currentText = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    debugPrint('Current screen text: $currentText');
  }
  expect(finder, findsWidgets);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
}

Future<void> _waitForTransientNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

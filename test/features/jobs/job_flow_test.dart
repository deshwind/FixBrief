import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/jobs/data/repositories/demo_job_repository.dart';
import 'package:fixbrief/features/jobs/presentation/providers/job_providers.dart';
import 'package:fixbrief/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:fixbrief/features/jobs/presentation/screens/jobs_screen.dart';
import 'package:fixbrief/features/jobs/presentation/screens/review_submission_screen.dart';
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

  testWidgets('customer jobs screen shows active and completed work', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoJobRepository('customer-user', UserRole.customer);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _testApp(
        environment: environment,
        repository: repository,
        child: const JobsScreen(),
      ),
    );
    await _pumpUntil(tester, find.text('2018 Ford Focus'));

    expect(find.text('My repairs'), findsOneWidget);
    expect(find.text('Active jobs'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Repair history'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Repair history'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Phone charging port'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Phone charging port'), findsOneWidget);
  });

  testWidgets('job detail exposes timeline, history, and customer completion', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoJobRepository('customer-user', UserRole.customer);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _testApp(
        environment: environment,
        repository: repository,
        child: const JobDetailScreen(jobId: 'demo-job-vehicle'),
      ),
    );
    await _pumpUntil(tester, find.text('Repair timeline'));

    expect(find.text('Request submitted'), findsOneWidget);
    expect(find.text('Quote accepted'), findsOneWidget);
    expect(find.text('Repair in progress'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Confirm repair completed'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Confirm repair completed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Status history'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Status history'), findsOneWidget);
  });

  testWidgets('completed job review asks for every customer rating category', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoJobRepository('customer-user', UserRole.customer);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _testApp(
        environment: environment,
        repository: repository,
        child: const ReviewSubmissionScreen(jobId: 'demo-job-phone'),
      ),
    );
    await _pumpUntil(tester, find.text('Overall experience'));

    expect(find.text('Quality of repair'), findsOneWidget);
    expect(find.text('Communication'), findsOneWidget);
    expect(find.text('Quote accuracy'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Publish review'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Publish review'), findsOneWidget);
  });
}

Widget _testApp({
  required AppEnvironment environment,
  required DemoJobRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      jobRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(theme: LiquidGlassTheme.light, home: child),
  );
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

import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/quotes/data/repositories/demo_quote_repository.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/presentation/providers/quote_providers.dart';
import 'package:fixbrief/features/quotes/presentation/screens/quote_comparison_screen.dart';
import 'package:fixbrief/features/quotes/presentation/screens/quote_editor_screen.dart';
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

  testWidgets('repairer sees complete quote form and live provisional total', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoQuoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          quoteRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: const QuoteEditorScreen(requestId: 'demo-request-vehicle'),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Prepare a quote'));

    expect(find.text(provisionalEstimateWarning), findsOneWidget);
    expect(find.text('£135–£475'), findsOneWidget);
    expect(find.text('Estimated costs'), findsOneWidget);
    expect(find.text('Availability and cover'), findsOneWidget);
    expect(find.text('Scope and conditions'), findsOneWidget);
    expect(find.text('Submit provisional quote'), findsOneWidget);
  });

  testWidgets('customer sees complete explained quote comparison', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = DemoQuoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          quoteRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: const QuoteComparisonScreen(requestId: 'demo-request-vehicle'),
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Compare quotes'));

    expect(find.text('3 repairer estimates'), findsOneWidget);
    expect(find.text('Strong overall fit'), findsOneWidget);
    expect(find.textContaining('not a cheapest-quote label'), findsOneWidget);
    expect(find.text('Accept quote'), findsNWidgets(3));
    expect(find.text(provisionalEstimateWarning), findsNWidgets(4));
  });
}

void _setPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(finder, findsWidgets);
}

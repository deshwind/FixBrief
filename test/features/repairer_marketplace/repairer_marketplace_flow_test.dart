import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/repairer_dashboard/presentation/screens/repairer_dashboard_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/data/repositories/demo_repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/marketplace_request_detail_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/matching_requests_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/repairer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const environment = AppEnvironment(
    flavor: AppFlavor.development,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'test-anon-key',
    useDemoAuthentication: true,
  );

  testWidgets('repairer discovers, filters, and opens a safe request', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: AppPaths.repairerDashboard,
      routes: [
        GoRoute(
          path: AppPaths.repairerDashboard,
          builder: (context, state) => const RepairerDashboardScreen(),
        ),
        GoRoute(
          path: AppPaths.repairerRequests,
          builder: (context, state) => const MatchingRequestsScreen(),
        ),
        GoRoute(
          path: AppPaths.repairerRequest,
          builder: (context, state) => MarketplaceRequestDetailScreen(
            requestId: state.pathParameters['requestId']!,
          ),
        ),
        GoRoute(
          path: AppPaths.repairerProfile,
          builder: (context, state) => RepairerProfileScreen(
            repairerId: state.pathParameters['repairerId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          repairerMarketplaceRepositoryProvider.overrideWithValue(
            DemoRepairerMarketplaceRepository(),
          ),
        ],
        child: MaterialApp.router(
          theme: LiquidGlassTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntil(tester, find.text('New matching requests'));

    expect(find.text('6 eligible requests'), findsOneWidget);
    expect(
      find.text('Exact address and customer identity hidden'),
      findsWidgets,
    );

    await _scrollToAndTap(tester, find.text('View all'));
    await _pumpUntil(tester, find.text('Matching requests'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('6 requests'), findsOneWidget);

    final visibleVehicleRequest = find.text('Ford Focus').hitTestable();
    expect(visibleVehicleRequest, findsOneWidget);
    await tester.tap(visibleVehicleRequest);
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntil(tester, find.text('Customer-approved repair brief'));
    expect(find.text('Privacy-safe marketplace view'), findsOneWidget);
    expect(find.textContaining('exact address stay private'), findsOneWidget);
    expect(
      find.text('AI-assisted assessment — not a confirmed diagnosis.'),
      findsOneWidget,
    );
    expect(find.text('Prepare or edit provisional quote'), findsOneWidget);

    router.go(AppPaths.repairerProfileFor('me'));
    await _pumpUntil(tester, find.text('Northline Repairs'));
    expect(find.text('Identity and business verified'), findsOneWidget);
    expect(find.text('Service coverage'), findsOneWidget);
    expect(
      find.textContaining('precise business and customer addresses'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(finder, findsWidgets);
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 500));
}

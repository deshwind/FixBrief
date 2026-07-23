import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('floating navigation exposes and selects each destination', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: Scaffold(
            bottomNavigationBar: LiquidGlassNavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => selectedIndex = index,
              destinations: const [
                LiquidGlassNavigationDestination(
                  icon: Icons.home_outlined,
                  label: 'Home',
                ),
                LiquidGlassNavigationDestination(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    await tester.tap(find.text('Messages'));

    expect(selectedIndex, 1);
  });

  testWidgets('floating snackbars do not block navigation destinations', (
    tester,
  ) async {
    var selectedIndex = 0;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LiquidGlassTheme.light,
          home: Scaffold(
            key: scaffoldKey,
            body: Stack(
              children: [
                const SizedBox.expand(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LiquidGlassNavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => selectedIndex = index,
                    destinations: const [
                      LiquidGlassNavigationDestination(
                        icon: Icons.home_outlined,
                        label: 'Home',
                      ),
                      LiquidGlassNavigationDestination(
                        icon: Icons.chat_bubble_outline,
                        label: 'Messages',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    ScaffoldMessenger.of(
      scaffoldKey.currentContext!,
    ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved successfully'), findsOneWidget);
    await tester.tap(find.text('Messages'));
    expect(selectedIndex, 1);
  });
}

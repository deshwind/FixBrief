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
}

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RepairerMarketplaceNavigation extends StatelessWidget {
  const RepairerMarketplaceNavigation({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: LiquidGlassNavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go(AppPaths.repairerDashboard);
                return;
              case 1:
                context.go(AppPaths.repairerRequests);
                return;
              case 2:
                context.go(AppPaths.repairerQuotes);
                return;
              case 3:
                _showLater(context, 'Customer messaging arrives in Stage 9.');
                return;
              case 4:
                context.go(AppPaths.repairerProfileFor('me'));
                return;
            }
          },
          destinations: const [
            LiquidGlassNavigationDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: 'Dashboard',
            ),
            LiquidGlassNavigationDestination(
              icon: Icons.manage_search_rounded,
              label: 'Requests',
            ),
            LiquidGlassNavigationDestination(
              icon: Icons.request_quote_outlined,
              selectedIcon: Icons.request_quote_rounded,
              label: 'Quotes',
            ),
            LiquidGlassNavigationDestination(
              icon: Icons.chat_bubble_outline_rounded,
              selectedIcon: Icons.chat_bubble_rounded,
              label: 'Messages',
            ),
            LiquidGlassNavigationDestination(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  static void _showLater(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

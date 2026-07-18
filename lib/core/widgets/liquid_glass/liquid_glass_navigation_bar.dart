import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

@immutable
class LiquidGlassNavigationDestination {
  const LiquidGlassNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    assert(destinations.length >= 2);
    assert(selectedIndex >= 0 && selectedIndex < destinations.length);

    final tokens = context.glassTokens;
    final colors = context.glassColors;
    final selectedColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LiquidGlassContainer(
        height: tokens.navigationHeight,
        radius: tokens.navigationRadius,
        padding: const EdgeInsets.all(7),
        semanticLabel: 'Primary navigation',
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _NavigationItem(
                  destination: destinations[index],
                  selected: selectedIndex == index,
                  selectedColor: selectedColor,
                  unselectedColor: colors.secondaryText,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final LiquidGlassNavigationDestination destination;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: AnimatedContainer(
              duration: MotionTokens.smallChange,
              curve: MotionTokens.emphasizedCurve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: selected
                    ? selectedColor.withValues(alpha: 0.14)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? selectedColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? destination.selectedIcon ?? destination.icon
                        : destination.icon,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

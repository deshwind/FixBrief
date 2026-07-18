import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidGlassAppBar({
    required this.title,
    this.actions,
    this.leading,
    this.scrolledUnder = false,
    this.large = false,
    super.key,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool scrolledUnder;
  final bool large;

  @override
  Size get preferredSize => Size.fromHeight(large ? 84 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.glassTokens;
    return AppBar(
      toolbarHeight: preferredSize.height,
      leading: leading,
      title: title,
      actions: actions,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LiquidGlassContainer(
        radius: 0,
        surfaceOpacity: (tokens.surfaceOpacity + (scrolledUnder ? 0.16 : 0.02))
            .clamp(0, 1)
            .toDouble(),
        showShadow: scrolledUnder,
        semanticLabel: 'Application bar',
        child: const SizedBox.expand(),
      ),
    );
  }
}

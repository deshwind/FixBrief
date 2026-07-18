import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

Future<T?> showLiquidGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: destructive ? 0.58 : 0.38),
    builder: (context) =>
        LiquidGlassDialog(destructive: destructive, child: builder(context)),
  );
}

class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({
    required this.child,
    this.destructive = false,
    super.key,
  });

  final Widget child;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glassTokens;
    final colors = context.glassColors;
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LiquidGlassContainer(
          radius: tokens.dialogRadius,
          padding: const EdgeInsets.all(24),
          tint: destructive ? colors.dangerSurface : null,
          surfaceOpacity: destructive ? 0.96 : null,
          enableBlur: !destructive,
          semanticLabel: destructive ? 'Destructive confirmation' : 'Dialog',
          child: child,
        ),
      ),
    );
  }
}

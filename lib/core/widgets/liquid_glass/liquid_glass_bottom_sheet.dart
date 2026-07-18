import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

Future<T?> showLiquidGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => LiquidGlassBottomSheet(child: builder(context)),
  );
}

class LiquidGlassBottomSheet extends StatelessWidget {
  const LiquidGlassBottomSheet({
    required this.child,
    this.showDragHandle = true,
    super.key,
  });

  final Widget child;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glassTokens;
    return LiquidGlassContainer(
      width: double.infinity,
      radius: tokens.dialogRadius,
      padding: EdgeInsets.fromLTRB(20, showDragHandle ? 10 : 24, 20, 24),
      semanticLabel: 'Bottom sheet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = true,
    this.maxWidth = 580,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FluidBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (showBack)
                                SizedBox.square(
                                  dimension: 48,
                                  child: LiquidGlassContainer(
                                    radius: 16,
                                    showShadow: false,
                                    child: IconButton(
                                      tooltip: 'Go back',
                                      onPressed: () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go(AppPaths.welcome);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const _BrandMark(),
                              const Spacer(),
                              const LiquidGlassPreviewSettingsButton(),
                            ],
                          ),
                          const SizedBox(height: 30),
                          if (showBack) ...[
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: _BrandMark(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: context.glassColors.secondaryText,
                                ),
                          ),
                          const SizedBox(height: 26),
                          LiquidGlassContainer(
                            padding: const EdgeInsets.all(22),
                            child: child,
                          ),
                        ],
                      ),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              colors: [LiquidGlassColors.coolBlue, LiquidGlassColors.cyan],
            ),
          ),
          child: const Icon(Icons.link_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text('FixBrief', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

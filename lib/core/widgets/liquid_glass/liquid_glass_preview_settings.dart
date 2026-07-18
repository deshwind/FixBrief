import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_bottom_sheet.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiquidGlassPreviewSettingsButton extends ConsumerWidget {
  const LiquidGlassPreviewSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.square(
      dimension: 48,
      child: LiquidGlassContainer(
        radius: 16,
        showShadow: false,
        child: IconButton(
          onPressed: () => showLiquidGlassBottomSheet<void>(
            context: context,
            builder: (context) => const _PreviewSettingsSheet(),
          ),
          tooltip: 'Preview appearance settings',
          icon: const Icon(Icons.tune_rounded),
        ),
      ),
    );
  }
}

class _PreviewSettingsSheet extends ConsumerWidget {
  const _PreviewSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final effects = ref.watch(accessibilityEffectsControllerProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Preview appearance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'These controls demonstrate the central theme and accessibility '
            'effect policies used by every glass component.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref.read(appThemeModeProvider.notifier).setMode(selection.first);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Visual effects',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final mode in EffectMode.values)
                LiquidGlassChip(
                  label: switch (mode) {
                    EffectMode.full => 'Full',
                    EffectMode.reduced => 'Reduced',
                    EffectMode.minimal => 'Minimal',
                  },
                  icon: switch (mode) {
                    EffectMode.full => Icons.blur_on_rounded,
                    EffectMode.reduced => Icons.blur_circular_rounded,
                    EffectMode.minimal => Icons.layers_clear_rounded,
                  },
                  selected: effects.mode == mode,
                  onSelected: (_) {
                    ref
                        .read(accessibilityEffectsControllerProvider.notifier)
                        .setMode(mode);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce transparency'),
            subtitle: const Text('Replaces blur with an opaque surface.'),
            value: effects.reduceTransparency,
            onChanged: ref
                .read(accessibilityEffectsControllerProvider.notifier)
                .setReduceTransparency,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Stops decorative and reveal animations.'),
            value: effects.reduceMotion,
            onChanged: ref
                .read(accessibilityEffectsControllerProvider.notifier)
                .setReduceMotion,
          ),
        ],
      ),
    );
  }
}

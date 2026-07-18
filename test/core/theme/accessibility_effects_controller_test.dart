import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessibilityEffectsState', () {
    test('high contrast selects the opaque minimal effect mode', () {
      const state = AccessibilityEffectsState();
      const mediaQuery = MediaQueryData(highContrast: true);

      expect(state.effectiveMode(mediaQuery), EffectMode.minimal);
      expect(state.blurSigma(LiquidGlassTokens.light, mediaQuery), 0);
      expect(state.surfaceOpacity(LiquidGlassTokens.light, mediaQuery), 0.96);
    });

    test('reduce motion and platform settings suppress motion', () {
      const state = AccessibilityEffectsState(reduceMotion: true);

      expect(state.motionAllowed(const MediaQueryData()), isFalse);
      expect(
        const AccessibilityEffectsState().motionAllowed(
          const MediaQueryData(disableAnimations: true),
        ),
        isFalse,
      );
    });

    test('reduced transparency raises opacity and halves blur', () {
      const state = AccessibilityEffectsState(mode: EffectMode.reduced);
      const mediaQuery = MediaQueryData();

      expect(
        state.blurSigma(LiquidGlassTokens.light, mediaQuery),
        LiquidGlassTokens.light.blurSigma * 0.5,
      );
      expect(
        state.surfaceOpacity(LiquidGlassTokens.light, mediaQuery),
        LiquidGlassTokens.light.surfaceOpacity + 0.16,
      );
    });
  });
}

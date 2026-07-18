import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EffectMode { full, reduced, minimal }

@immutable
class AccessibilityEffectsState {
  const AccessibilityEffectsState({
    this.mode = EffectMode.full,
    this.reduceTransparency = false,
    this.reduceMotion = false,
  });

  final EffectMode mode;
  final bool reduceTransparency;
  final bool reduceMotion;

  AccessibilityEffectsState copyWith({
    EffectMode? mode,
    bool? reduceTransparency,
    bool? reduceMotion,
  }) {
    return AccessibilityEffectsState(
      mode: mode ?? this.mode,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  EffectMode effectiveMode(MediaQueryData mediaQuery) {
    if (reduceTransparency || mediaQuery.highContrast) {
      return EffectMode.minimal;
    }
    return mode;
  }

  bool motionAllowed(MediaQueryData mediaQuery) {
    return !reduceMotion &&
        !mediaQuery.disableAnimations &&
        !mediaQuery.accessibleNavigation &&
        effectiveMode(mediaQuery) != EffectMode.minimal;
  }

  double blurSigma(LiquidGlassTokens tokens, MediaQueryData mediaQuery) {
    return switch (effectiveMode(mediaQuery)) {
      EffectMode.full => tokens.blurSigma,
      EffectMode.reduced => tokens.blurSigma * 0.5,
      EffectMode.minimal => 0,
    };
  }

  double surfaceOpacity(LiquidGlassTokens tokens, MediaQueryData mediaQuery) {
    return switch (effectiveMode(mediaQuery)) {
      EffectMode.full => tokens.surfaceOpacity,
      EffectMode.reduced =>
        (tokens.surfaceOpacity + 0.16).clamp(0, 1).toDouble(),
      EffectMode.minimal => 0.96,
    };
  }
}

final accessibilityEffectsControllerProvider =
    NotifierProvider<AccessibilityEffectsController, AccessibilityEffectsState>(
      AccessibilityEffectsController.new,
    );

class AccessibilityEffectsController
    extends Notifier<AccessibilityEffectsState> {
  @override
  AccessibilityEffectsState build() => const AccessibilityEffectsState();

  void setMode(EffectMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setReduceTransparency(bool value) {
    state = state.copyWith(reduceTransparency: value);
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
  }
}

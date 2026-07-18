import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get materialMode {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeController, AppThemeMode>(
      AppThemeModeController.new,
    );

class AppThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  void setMode(AppThemeMode mode) {
    state = mode;
  }

  void toggleForPreview(Brightness currentBrightness) {
    state = currentBrightness == Brightness.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
  }
}

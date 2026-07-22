import 'package:fixbrief/core/config/app_environment.dart';
import 'package:fixbrief/core/routing/app_router.dart';
import 'package:fixbrief/core/theme/app_theme_mode.dart';
import 'package:fixbrief/core/theme/liquid_glass_theme.dart';
import 'package:fixbrief/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FixBriefApp extends ConsumerStatefulWidget {
  const FixBriefApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  ConsumerState<FixBriefApp> createState() => _FixBriefAppState();
}

class _FixBriefAppState extends ConsumerState<FixBriefApp> {
  late final AuthRouterRefresh _routerRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _routerRefresh = AuthRouterRefresh(ref);
    _router = buildAppRouter(ref, _routerRefresh);
  }

  @override
  void dispose() {
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsControllerProvider);
    final selectedThemeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'FixBrief',
      debugShowCheckedModeBanner: !widget.environment.isProduction,
      theme: LiquidGlassTheme.light,
      darkTheme: LiquidGlassTheme.dark,
      themeMode: selectedThemeMode.materialMode,
      routerConfig: _router,
    );
  }
}

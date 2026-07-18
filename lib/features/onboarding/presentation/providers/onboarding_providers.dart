import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_identity_store.dart';
import 'package:fixbrief/features/onboarding/data/demo/demo_onboarding_repository.dart';
import 'package:fixbrief/features/onboarding/data/repositories/supabase_onboarding_repository.dart';
import 'package:fixbrief/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final demoIdentityStoreProvider = Provider<DemoIdentityStore>((ref) {
  final store = DemoIdentityStore();
  ref.onDispose(() {
    unawaited(store.dispose());
  });
  return store;
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  if (environment.useDemoAuthentication) {
    return DemoOnboardingRepository(ref.watch(demoIdentityStoreProvider));
  }
  return SupabaseOnboardingRepository(ref.watch(supabaseClientProvider));
});

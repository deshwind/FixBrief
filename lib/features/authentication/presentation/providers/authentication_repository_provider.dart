import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_authentication_repository.dart';
import 'package:fixbrief/features/authentication/data/repositories/supabase_authentication_repository.dart';
import 'package:fixbrief/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:fixbrief/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authenticationRepositoryProvider = Provider<AuthenticationRepository>((
  ref,
) {
  final environment = ref.watch(appEnvironmentProvider);
  if (environment.useDemoAuthentication) {
    return DemoAuthenticationRepository(ref.watch(demoIdentityStoreProvider));
  }
  return SupabaseAuthenticationRepository(ref.watch(supabaseClientProvider));
});

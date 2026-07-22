import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/jobs/data/repositories/demo_job_repository.dart';
import 'package:fixbrief/features/jobs/data/repositories/supabase_job_repository.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final JobRepository repository;
  if (environment.useDemoAuthentication) {
    final auth = ref.watch(authSessionControllerProvider);
    repository = DemoJobRepository(
      auth.user?.id ?? 'demo-user',
      auth.onboarding.role ?? UserRole.customer,
    );
  } else {
    repository = SupabaseJobRepository(ref.watch(supabaseClientProvider));
  }
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final jobsProvider = StreamProvider<List<RepairJob>>((ref) {
  return ref.watch(jobRepositoryProvider).watchJobs();
});

final jobProvider = StreamProvider.autoDispose.family<RepairJob?, String>((
  ref,
  jobId,
) {
  return ref.watch(jobRepositoryProvider).watchJob(jobId);
});

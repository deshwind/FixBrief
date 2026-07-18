import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/repair_requests/data/local/repair_draft_database.dart';
import 'package:fixbrief/features/repair_requests/data/repositories/demo_repair_request_repository.dart';
import 'package:fixbrief/features/repair_requests/data/repositories/supabase_repair_request_repository.dart';
import 'package:fixbrief/features/repair_requests/data/services/repair_media_services.dart';
import 'package:fixbrief/features/repair_requests/domain/repositories/repair_request_repository.dart';
import 'package:fixbrief/features/repair_requests/presentation/controllers/repair_request_wizard_controller.dart';
import 'package:fixbrief/features/repair_requests/presentation/controllers/repair_request_wizard_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final repairDraftDatabaseProvider = Provider<RepairDraftDatabase>((ref) {
  final database = RepairDraftDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final repairRequestRepositoryProvider = Provider<RepairRequestRepository>((
  ref,
) {
  final database = ref.watch(repairDraftDatabaseProvider);
  if (ref.watch(appEnvironmentProvider).useDemoAuthentication) {
    return DemoRepairRequestRepository(database);
  }
  return SupabaseRepairRequestRepository(
    ref.watch(supabaseClientProvider),
    database,
  );
});

final repairMediaPickerProvider = Provider<RepairMediaPicker>((ref) {
  return DeviceRepairMediaPicker();
});

final repairSpeechServiceProvider = Provider<RepairSpeechService>((ref) {
  return DeviceRepairSpeechService();
});

final repairAudioRecorderProvider = Provider<RepairAudioRecorder>((ref) {
  final recorder = DeviceRepairAudioRecorder();
  ref.onDispose(() => unawaited(recorder.dispose()));
  return recorder;
});

final repairRequestWizardControllerProvider =
    NotifierProvider<RepairRequestWizardController, RepairRequestWizardState>(
      RepairRequestWizardController.new,
    );

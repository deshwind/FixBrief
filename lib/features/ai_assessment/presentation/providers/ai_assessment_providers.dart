import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/ai_assessment/data/repositories/demo_ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/data/repositories/supabase_ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/presentation/controllers/ai_assessment_controller.dart';
import 'package:fixbrief/features/ai_assessment/presentation/controllers/ai_assessment_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiAssessmentRepositoryProvider = Provider<AiAssessmentRepository>((ref) {
  if (ref.watch(appEnvironmentProvider).useDemoAuthentication) {
    return DemoAiAssessmentRepository();
  }
  return SupabaseAiAssessmentRepository(ref.watch(supabaseClientProvider));
});

final aiAssessmentControllerProvider =
    NotifierProvider<AiAssessmentController, AiAssessmentState>(
      AiAssessmentController.new,
    );

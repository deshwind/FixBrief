import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';

abstract interface class AiAssessmentRepository {
  Future<AiAssessment> generate(
    AiAssessmentRequest request, {
    bool regenerate = false,
  });

  Future<AiAssessment> answerFollowUpQuestions(
    AiAssessmentRequest request,
    Map<String, String> answers,
  );

  Future<void> saveRepairBrief(String requestId, RepairBriefEdits edits);

  Future<void> publish(String requestId, RepairBriefEdits edits);
}

class AiAssessmentFailure implements Exception {
  const AiAssessmentFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;

  @override
  String toString() => message;
}

abstract final class AiAssessmentValidator {
  static AiAssessment validate(AiAssessment assessment) {
    if (assessment.problemSummary.trim().isEmpty ||
        assessment.problemSummary.length > 5000) {
      throw const AiAssessmentFailure(
        'The assessment response was incomplete. Please try again.',
      );
    }
    if (assessment.disclaimer != aiAssessmentDisclaimer) {
      throw const AiAssessmentFailure(
        'The assessment response did not pass the uncertainty check.',
      );
    }
    if (assessment.repairBrief.trim().isEmpty ||
        assessment.repairBrief.length > 15000 ||
        assessment.possibleCauses.length > 8 ||
        assessment.followUpQuestions.length > 8) {
      throw const AiAssessmentFailure(
        'The assessment response did not match the required format.',
      );
    }
    for (final cause in assessment.possibleCauses) {
      if (cause.name.trim().isEmpty ||
          cause.reason.trim().isEmpty ||
          cause.confidence < 0 ||
          cause.confidence > 1) {
        throw const AiAssessmentFailure(
          'A possible cause in the assessment was invalid.',
        );
      }
    }
    if (assessment.hasHighSafetyRisk && !assessment.stopUsingItem) {
      throw const AiAssessmentFailure(
        'The assessment response did not pass the safety check.',
      );
    }
    return assessment;
  }
}

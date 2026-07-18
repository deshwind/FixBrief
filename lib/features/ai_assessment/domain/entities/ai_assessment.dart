import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_assessment.freezed.dart';
part 'ai_assessment.g.dart';

const aiAssessmentDisclaimer =
    'AI-assisted assessment — not a confirmed diagnosis.';

@JsonEnum(fieldRename: FieldRename.snake)
enum AiAssessmentUrgency { low, medium, high, emergency }

@JsonEnum(fieldRename: FieldRename.snake)
enum AiSafetyRisk { none, low, moderate, high, critical }

@freezed
abstract class AiPossibleCause with _$AiPossibleCause {
  const factory AiPossibleCause({
    required String id,
    required String name,
    required double confidence,
    required String reason,
    @Default(false) bool hidden,
  }) = _AiPossibleCause;

  factory AiPossibleCause.fromJson(Map<String, Object?> json) =>
      _$AiPossibleCauseFromJson(json);
}

@freezed
abstract class AiFollowUpQuestion with _$AiFollowUpQuestion {
  const factory AiFollowUpQuestion({
    required String id,
    required String question,
    @Default(false) bool isEssential,
    @Default('') String answer,
    @Default(false) bool isSkipped,
  }) = _AiFollowUpQuestion;

  factory AiFollowUpQuestion.fromJson(Map<String, Object?> json) =>
      _$AiFollowUpQuestionFromJson(json);
}

@freezed
abstract class AiAssessment with _$AiAssessment {
  const factory AiAssessment({
    required String id,
    required String requestId,
    required int version,
    required String itemName,
    required String problemDescription,
    required String problemSummary,
    required List<String> possibleFaultCategories,
    required List<AiPossibleCause> possibleCauses,
    required AiAssessmentUrgency urgency,
    required AiSafetyRisk safetyRisk,
    required bool stopUsingItem,
    required String safetyWarning,
    required String recommendedProfessional,
    required List<String> recommendedSpecialisations,
    required List<AiFollowUpQuestion> followUpQuestions,
    required List<String> missingInformation,
    required List<String> recommendedEvidence,
    required String inspectionRecommendation,
    required String repairBrief,
    @Default(aiAssessmentDisclaimer) String disclaimer,
    @Default(false) bool isFallback,
    required DateTime generatedAt,
  }) = _AiAssessment;

  const AiAssessment._();

  factory AiAssessment.fromJson(Map<String, Object?> json) =>
      _$AiAssessmentFromJson(json);

  bool get hasHighSafetyRisk =>
      safetyRisk == AiSafetyRisk.high || safetyRisk == AiSafetyRisk.critical;

  bool get hasQuestions => followUpQuestions.isNotEmpty;
}

@freezed
abstract class RepairBriefEdits with _$RepairBriefEdits {
  const factory RepairBriefEdits({
    required String repairBrief,
    required String itemName,
    required String problemDescription,
    @Default(<String>[]) List<String> hiddenCauseIds,
  }) = _RepairBriefEdits;

  factory RepairBriefEdits.fromJson(Map<String, Object?> json) =>
      _$RepairBriefEditsFromJson(json);
}

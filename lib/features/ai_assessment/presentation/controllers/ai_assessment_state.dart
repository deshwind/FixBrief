import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:flutter/foundation.dart';

enum AiAssessmentPhase {
  idle,
  processing,
  result,
  followUp,
  review,
  saving,
  published,
  error,
}

@immutable
class AiAssessmentState {
  const AiAssessmentState({
    this.phase = AiAssessmentPhase.idle,
    this.request,
    this.assessment,
    this.processingStatusIndex = 0,
    this.answers = const <String, String>{},
    this.skippedQuestionIds = const <String>{},
    this.hiddenCauseIds = const <String>{},
    this.editedRepairBrief = '',
    this.editedItemName = '',
    this.editedProblemDescription = '',
    this.isListening = false,
    this.listeningQuestionId,
    this.errorMessage,
    this.noticeMessage,
  });

  final AiAssessmentPhase phase;
  final AiAssessmentRequest? request;
  final AiAssessment? assessment;
  final int processingStatusIndex;
  final Map<String, String> answers;
  final Set<String> skippedQuestionIds;
  final Set<String> hiddenCauseIds;
  final String editedRepairBrief;
  final String editedItemName;
  final String editedProblemDescription;
  final bool isListening;
  final String? listeningQuestionId;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isBusy =>
      phase == AiAssessmentPhase.processing ||
      phase == AiAssessmentPhase.saving;

  AiAssessmentState copyWith({
    AiAssessmentPhase? phase,
    AiAssessmentRequest? request,
    AiAssessment? assessment,
    int? processingStatusIndex,
    Map<String, String>? answers,
    Set<String>? skippedQuestionIds,
    Set<String>? hiddenCauseIds,
    String? editedRepairBrief,
    String? editedItemName,
    String? editedProblemDescription,
    bool? isListening,
    String? listeningQuestionId,
    String? errorMessage,
    String? noticeMessage,
    bool clearListeningQuestion = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return AiAssessmentState(
      phase: phase ?? this.phase,
      request: request ?? this.request,
      assessment: assessment ?? this.assessment,
      processingStatusIndex:
          processingStatusIndex ?? this.processingStatusIndex,
      answers: answers ?? this.answers,
      skippedQuestionIds: skippedQuestionIds ?? this.skippedQuestionIds,
      hiddenCauseIds: hiddenCauseIds ?? this.hiddenCauseIds,
      editedRepairBrief: editedRepairBrief ?? this.editedRepairBrief,
      editedItemName: editedItemName ?? this.editedItemName,
      editedProblemDescription:
          editedProblemDescription ?? this.editedProblemDescription,
      isListening: isListening ?? this.isListening,
      listeningQuestionId: clearListeningQuestion
          ? null
          : listeningQuestionId ?? this.listeningQuestionId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

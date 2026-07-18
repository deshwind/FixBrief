import 'dart:async';

import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/presentation/controllers/ai_assessment_state.dart';
import 'package:fixbrief/features/ai_assessment/presentation/providers/ai_assessment_providers.dart';
import 'package:fixbrief/features/repair_requests/data/services/repair_media_services.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiAssessmentController extends Notifier<AiAssessmentState> {
  static const processingStatuses = <String>[
    'Reviewing your description',
    'Organising symptoms',
    'Checking for safety concerns',
    'Reviewing uploaded evidence',
    'Preparing your repair brief',
  ];

  late AiAssessmentRepository _repository;
  late RepairSpeechService _speech;
  Timer? _statusTimer;

  @override
  AiAssessmentState build() {
    _repository = ref.watch(aiAssessmentRepositoryProvider);
    _speech = ref.watch(repairSpeechServiceProvider);
    ref.onDispose(() {
      _statusTimer?.cancel();
      if (_speech.isListening) {
        unawaited(_speech.stop());
      }
    });
    return const AiAssessmentState();
  }

  Future<void> start(
    AiAssessmentRequest request, {
    bool regenerate = false,
  }) async {
    if (!regenerate &&
        state.request?.requestId == request.requestId &&
        state.phase != AiAssessmentPhase.idle &&
        state.phase != AiAssessmentPhase.error) {
      return;
    }
    await _stopListening();
    _startStatusCycle();
    state = state.copyWith(
      phase: AiAssessmentPhase.processing,
      request: request,
      processingStatusIndex: 0,
      clearError: true,
      clearNotice: true,
    );
    try {
      final assessment = await _repository.generate(
        request,
        regenerate: regenerate,
      );
      _statusTimer?.cancel();
      state = state.copyWith(
        phase: AiAssessmentPhase.result,
        assessment: assessment,
        editedRepairBrief: assessment.repairBrief,
        editedItemName: assessment.itemName,
        editedProblemDescription: assessment.problemDescription,
        answers: <String, String>{
          for (final question in assessment.followUpQuestions)
            if (question.answer.isNotEmpty) question.id: question.answer,
        },
        skippedQuestionIds: <String>{
          for (final question in assessment.followUpQuestions)
            if (question.isSkipped) question.id,
        },
        hiddenCauseIds: <String>{
          for (final cause in assessment.possibleCauses)
            if (cause.hidden) cause.id,
        },
      );
    } on AiAssessmentFailure catch (failure) {
      _setFailure(failure.message);
    } on Object {
      _setFailure(
        'The assessment could not be completed. Your repair request is safe.',
      );
    }
  }

  void showFollowUp() {
    if (state.assessment?.hasQuestions ?? false) {
      state = state.copyWith(
        phase: AiAssessmentPhase.followUp,
        clearError: true,
        clearNotice: true,
      );
    }
  }

  void showResult() {
    state = state.copyWith(
      phase: AiAssessmentPhase.result,
      clearError: true,
      clearNotice: true,
    );
  }

  void showReview() {
    state = state.copyWith(
      phase: AiAssessmentPhase.review,
      clearError: true,
      clearNotice: true,
    );
  }

  void updateAnswer(String questionId, String answer) {
    final answers = <String, String>{...state.answers};
    if (answer.trim().isEmpty) {
      answers.remove(questionId);
    } else {
      answers[questionId] = answer;
    }
    final skipped = <String>{...state.skippedQuestionIds}..remove(questionId);
    state = state.copyWith(
      answers: answers,
      skippedQuestionIds: skipped,
      clearError: true,
      clearNotice: true,
    );
  }

  void toggleSkipped(AiFollowUpQuestion question) {
    if (question.isEssential) {
      state = state.copyWith(
        errorMessage: 'This question is needed to prepare a useful brief.',
      );
      return;
    }
    final skipped = <String>{...state.skippedQuestionIds};
    final answers = <String, String>{...state.answers};
    if (!skipped.add(question.id)) {
      skipped.remove(question.id);
    } else {
      answers.remove(question.id);
    }
    state = state.copyWith(
      skippedQuestionIds: skipped,
      answers: answers,
      clearError: true,
      clearNotice: true,
    );
  }

  Future<void> submitFollowUps() async {
    final assessment = state.assessment;
    final request = state.request;
    if (assessment == null || request == null) {
      return;
    }
    for (final question in assessment.followUpQuestions) {
      if (question.isEssential &&
          (state.answers[question.id]?.trim().isEmpty ?? true)) {
        state = state.copyWith(
          errorMessage:
              'Please answer the required question before continuing.',
        );
        return;
      }
    }
    await _stopListening();
    final submitted = <String, String>{
      ...state.answers.map((key, value) => MapEntry(key, value.trim())),
      for (final id in state.skippedQuestionIds) id: '__skipped__',
    };
    final updatedRequest = request.copyWith(followUpAnswers: submitted);
    _startStatusCycle(startAt: 1);
    state = state.copyWith(
      phase: AiAssessmentPhase.processing,
      request: updatedRequest,
      processingStatusIndex: 1,
      clearError: true,
      clearNotice: true,
    );
    try {
      final next = await _repository.answerFollowUpQuestions(
        updatedRequest,
        submitted,
      );
      _statusTimer?.cancel();
      state = state.copyWith(
        phase: AiAssessmentPhase.result,
        assessment: next,
        editedRepairBrief: next.repairBrief,
        noticeMessage: 'Your answers have been added to the repair brief.',
      );
    } on AiAssessmentFailure catch (failure) {
      _setFailure(failure.message);
    } on Object {
      _setFailure('Your answers could not be processed. Please try again.');
    }
  }

  Future<void> toggleVoice(String questionId) async {
    if (state.isListening) {
      await _stopListening();
      return;
    }
    final prefix = state.answers[questionId]?.trim() ?? '';
    final started = await _speech.start((words) {
      final value = <String>[
        if (prefix.isNotEmpty) prefix,
        words.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
      updateAnswer(questionId, value);
    });
    state = state.copyWith(
      isListening: started,
      listeningQuestionId: started ? questionId : null,
      clearListeningQuestion: !started,
      errorMessage: started
          ? null
          : 'Voice input is unavailable. Check microphone permission.',
      clearError: started,
    );
  }

  void updateRepairBrief(String value) {
    state = state.copyWith(editedRepairBrief: value, clearError: true);
  }

  void updateItemName(String value) {
    state = state.copyWith(editedItemName: value, clearError: true);
  }

  void updateProblemDescription(String value) {
    state = state.copyWith(editedProblemDescription: value, clearError: true);
  }

  void toggleCauseVisibility(String causeId) {
    final hidden = <String>{...state.hiddenCauseIds};
    if (!hidden.add(causeId)) {
      hidden.remove(causeId);
    }
    state = state.copyWith(hiddenCauseIds: hidden, clearNotice: true);
  }

  Future<void> saveBrief() async {
    final requestId = state.request?.requestId;
    if (requestId == null || !_validateEdits()) {
      return;
    }
    state = state.copyWith(
      phase: AiAssessmentPhase.saving,
      clearError: true,
      clearNotice: true,
    );
    try {
      await _repository.saveRepairBrief(requestId, _edits);
      state = state.copyWith(
        phase: AiAssessmentPhase.review,
        request: state.request?.copyWith(
          itemName: state.editedItemName.trim(),
          problemDescription: state.editedProblemDescription.trim(),
        ),
        noticeMessage: 'Repair brief saved.',
      );
    } on AiAssessmentFailure catch (failure) {
      state = state.copyWith(
        phase: AiAssessmentPhase.review,
        errorMessage: failure.message,
      );
    } on Object {
      state = state.copyWith(
        phase: AiAssessmentPhase.review,
        errorMessage: 'The brief could not be saved. Please try again.',
      );
    }
  }

  Future<void> publish() async {
    final requestId = state.request?.requestId;
    if (requestId == null || !_validateEdits()) {
      return;
    }
    state = state.copyWith(
      phase: AiAssessmentPhase.saving,
      clearError: true,
      clearNotice: true,
    );
    try {
      await _repository.publish(requestId, _edits);
      state = state.copyWith(phase: AiAssessmentPhase.published);
    } on AiAssessmentFailure catch (failure) {
      state = state.copyWith(
        phase: AiAssessmentPhase.review,
        errorMessage: failure.message,
      );
    } on Object {
      state = state.copyWith(
        phase: AiAssessmentPhase.review,
        errorMessage: 'The request could not be published. Please try again.',
      );
    }
  }

  Future<void> regenerate() async {
    final request = state.request;
    if (request != null) {
      await start(request, regenerate: true);
    }
  }

  bool _validateEdits() {
    if (state.editedItemName.trim().length < 2) {
      state = state.copyWith(errorMessage: 'Enter the item name.');
      return false;
    }
    if (state.editedProblemDescription.trim().length < 10) {
      state = state.copyWith(
        errorMessage: 'Add a little more detail about the problem.',
      );
      return false;
    }
    if (state.editedRepairBrief.trim().length < 20) {
      state = state.copyWith(
        errorMessage: 'The repair brief needs a little more detail.',
      );
      return false;
    }
    return true;
  }

  RepairBriefEdits get _edits => RepairBriefEdits(
    repairBrief: state.editedRepairBrief.trim(),
    itemName: state.editedItemName.trim(),
    problemDescription: state.editedProblemDescription.trim(),
    hiddenCauseIds: state.hiddenCauseIds.toList(),
  );

  Future<void> _stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (state.isListening) {
      state = state.copyWith(isListening: false, clearListeningQuestion: true);
    }
  }

  void _startStatusCycle({int startAt = 0}) {
    _statusTimer?.cancel();
    var index = startAt;
    _statusTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      index = (index + 1).clamp(0, processingStatuses.length - 1);
      state = state.copyWith(processingStatusIndex: index);
      if (index == processingStatuses.length - 1) {
        _statusTimer?.cancel();
      }
    });
  }

  void _setFailure(String message) {
    _statusTimer?.cancel();
    state = state.copyWith(
      phase: AiAssessmentPhase.error,
      errorMessage: message,
    );
  }
}

import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:flutter/foundation.dart';

@immutable
class RepairRequestWizardState {
  const RepairRequestWizardState({
    this.draft,
    this.isLoading = true,
    this.isSaving = false,
    this.isSubmitting = false,
    this.isOnline = true,
    this.isListening = false,
    this.isRecording = false,
    this.errorMessage,
    this.noticeMessage,
    this.submittedRequestId,
  });

  final RepairRequestDraft? draft;
  final bool isLoading;
  final bool isSaving;
  final bool isSubmitting;
  final bool isOnline;
  final bool isListening;
  final bool isRecording;
  final String? errorMessage;
  final String? noticeMessage;
  final String? submittedRequestId;

  RepairRequestWizardState copyWith({
    RepairRequestDraft? draft,
    bool? isLoading,
    bool? isSaving,
    bool? isSubmitting,
    bool? isOnline,
    bool? isListening,
    bool? isRecording,
    String? errorMessage,
    String? noticeMessage,
    String? submittedRequestId,
    bool clearError = false,
    bool clearNotice = false,
    bool clearSubmission = false,
  }) {
    return RepairRequestWizardState(
      draft: draft ?? this.draft,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isOnline: isOnline ?? this.isOnline,
      isListening: isListening ?? this.isListening,
      isRecording: isRecording ?? this.isRecording,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
      submittedRequestId: clearSubmission
          ? null
          : submittedRequestId ?? this.submittedRequestId,
    );
  }
}

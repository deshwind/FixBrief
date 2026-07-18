import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/repair_requests/data/services/repair_media_services.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_category.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/domain/repair_request_validation.dart';
import 'package:fixbrief/features/repair_requests/domain/repositories/repair_request_repository.dart';
import 'package:fixbrief/features/repair_requests/presentation/controllers/repair_request_wizard_state.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class RepairRequestWizardController extends Notifier<RepairRequestWizardState> {
  static const _autosaveDelay = Duration(milliseconds: 500);
  static const _maxImages = 8;
  static const _maxVideos = 2;
  static const _maxAudio = 3;

  late RepairRequestRepository _repository;
  late RepairMediaPicker _mediaPicker;
  late RepairSpeechService _speech;
  late RepairAudioRecorder _recorder;
  final _uuid = const Uuid();
  Timer? _autosaveTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  RepairRequestWizardState build() {
    _repository = ref.watch(repairRequestRepositoryProvider);
    _mediaPicker = ref.watch(repairMediaPickerProvider);
    _speech = ref.watch(repairSpeechServiceProvider);
    _recorder = ref.watch(repairAudioRecorderProvider);

    ref.onDispose(() {
      _autosaveTimer?.cancel();
      unawaited(_connectivitySubscription?.cancel());
    });
    unawaited(Future<void>.microtask(_initialize));
    return const RepairRequestWizardState();
  }

  Future<void> _initialize() async {
    final user = ref.read(authSessionControllerProvider).user;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Your session expired. Sign in again.',
      );
      return;
    }
    try {
      final existing = await _repository.loadActiveDraft(user.id);
      final now = DateTime.now();
      final draft =
          existing ??
          RepairRequestDraft.empty(
            id: _uuid.v4(),
            customerId: user.id,
            now: now,
          );
      state = state.copyWith(draft: draft, isLoading: false, clearError: true);
      if (existing == null) {
        await _repository.saveDraft(draft);
      }
    } on Object catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Your saved draft could not be opened.',
      );
    }

    if (ref.read(appEnvironmentProvider).useDemoAuthentication) {
      return;
    }

    final connectivity = Connectivity();
    try {
      _setConnectivity(await connectivity.checkConnectivity());
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        _setConnectivity,
      );
    } on Object catch (_) {
      // Native connectivity may be unavailable in widget tests. Submission
      // remains optimistic and reports any actual network failure safely.
    }
  }

  void _setConnectivity(List<ConnectivityResult> results) {
    state = state.copyWith(
      isOnline: !results.contains(ConnectivityResult.none),
    );
  }

  void clearFeedback() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }

  void update(RepairRequestDraft Function(RepairRequestDraft draft) change) {
    final current = state.draft;
    if (current == null || current.status != RepairDraftStatus.draft) {
      return;
    }
    state = state.copyWith(
      draft: change(current),
      clearError: true,
      clearNotice: true,
    );
    _scheduleAutosave();
  }

  void selectCategory(RepairCategory category) {
    update(
      (draft) => draft.copyWith(
        categorySlug: category.slug,
        categoryLabel: category.label,
        subcategory: category.subcategories.first,
      ),
    );
  }

  String? validateStep(int step) {
    final draft = state.draft;
    if (draft == null) {
      return 'The draft is still loading.';
    }
    final error = RepairRequestValidation.stepError(draft, step);
    if (error != null) {
      state = state.copyWith(errorMessage: error);
    }
    return error;
  }

  Future<void> setCurrentStep(int step) async {
    update((draft) => draft.copyWith(currentStep: step.clamp(0, 5)));
    await saveNow();
  }

  void addTypedSymptom(SymptomKind kind, String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      return;
    }
    update(
      (draft) => draft.copyWith(
        symptoms: <RepairSymptom>[
          ...draft.symptoms,
          RepairSymptom(id: _uuid.v4(), kind: kind, description: trimmed),
        ],
      ),
    );
  }

  void toggleSuggestedSymptom(String description) {
    final current = state.draft;
    if (current == null) {
      return;
    }
    final existing = current.symptoms
        .where(
          (item) =>
              item.source == SymptomSource.suggested &&
              item.description == description,
        )
        .firstOrNull;
    if (existing != null) {
      update(
        (draft) => draft.copyWith(
          symptoms: draft.symptoms
              .where((item) => item.id != existing.id)
              .toList(),
        ),
      );
      return;
    }
    update(
      (draft) => draft.copyWith(
        symptoms: <RepairSymptom>[
          ...draft.symptoms,
          RepairSymptom(
            id: _uuid.v4(),
            kind: _kindForSuggested(description),
            description: description,
            source: SymptomSource.suggested,
          ),
        ],
      ),
    );
  }

  void removeSymptom(String id) {
    update(
      (draft) => draft.copyWith(
        symptoms: draft.symptoms.where((item) => item.id != id).toList(),
      ),
    );
  }

  Future<void> toggleSpeechInput() async {
    if (state.isListening) {
      await _speech.stop();
      state = state.copyWith(isListening: false, noticeMessage: 'Voice added.');
      return;
    }
    final prefix = state.draft?.problemDescription.trim() ?? '';
    final started = await _speech.start((words) {
      final spoken = words.trim();
      update(
        (draft) => draft.copyWith(
          problemDescription: [
            if (prefix.isNotEmpty) prefix,
            if (spoken.isNotEmpty) spoken,
          ].join(' '),
        ),
      );
    });
    state = state.copyWith(
      isListening: started,
      errorMessage: started
          ? null
          : 'Speech recognition is unavailable or microphone access was denied.',
      clearError: started,
    );
  }

  Future<void> toggleAudioRecording() async {
    if (state.isRecording) {
      final evidence = await _recorder.stop();
      state = state.copyWith(isRecording: false);
      if (evidence != null) {
        _addEvidence(<RepairEvidence>[evidence]);
        state = state.copyWith(noticeMessage: 'Audio note saved privately.');
      }
      return;
    }
    final draft = state.draft;
    if (draft != null && draft.audioCount >= _maxAudio) {
      state = state.copyWith(errorMessage: 'You can add up to 3 audio files.');
      return;
    }
    final started = await _recorder.start();
    state = state.copyWith(
      isRecording: started,
      errorMessage: started ? null : 'Microphone access was not granted.',
      clearError: started,
    );
  }

  Future<void> finishActiveInput() async {
    if (state.isListening) {
      await _speech.stop();
      state = state.copyWith(isListening: false);
    }
    if (state.isRecording) {
      await toggleAudioRecording();
    }
  }

  Future<void> pickPhotos() async {
    try {
      _addEvidence(await _mediaPicker.pickPhotos());
    } on Object catch (_) {
      state = state.copyWith(errorMessage: 'Those photos could not be added.');
    }
  }

  Future<void> pickVideo() async {
    try {
      final item = await _mediaPicker.pickVideo();
      if (item != null) {
        _addEvidence(<RepairEvidence>[item]);
      }
    } on Object catch (_) {
      state = state.copyWith(errorMessage: 'That video could not be added.');
    }
  }

  Future<void> pickDocument(RepairEvidenceKind kind) async {
    try {
      final item = await _mediaPicker.pickDocument(kind);
      if (item != null) {
        _addEvidence(<RepairEvidence>[item]);
      }
    } on Object catch (_) {
      state = state.copyWith(errorMessage: 'That file could not be added.');
    }
  }

  void _addEvidence(List<RepairEvidence> candidates) {
    final draft = state.draft;
    if (draft == null || candidates.isEmpty) {
      return;
    }
    final accepted = <RepairEvidence>[];
    var images = draft.imageCount;
    var videos = draft.videoCount;
    var audio = draft.audioCount;
    String? rejection;
    for (final candidate in candidates) {
      final sizeError = _sizeError(candidate);
      if (sizeError != null) {
        rejection = sizeError;
        continue;
      }
      if (candidate.isImage && images >= _maxImages) {
        rejection = 'You can add up to 8 images.';
        continue;
      }
      if (candidate.isVideo && videos >= _maxVideos) {
        rejection = 'You can add up to 2 videos.';
        continue;
      }
      if (candidate.isAudio && audio >= _maxAudio) {
        rejection = 'You can add up to 3 audio files.';
        continue;
      }
      final item = candidate.copyWith(
        sortOrder: draft.evidence.length + accepted.length,
      );
      accepted.add(item);
      if (item.isImage) {
        images++;
      }
      if (item.isVideo) {
        videos++;
      }
      if (item.isAudio) {
        audio++;
      }
    }
    if (accepted.isNotEmpty) {
      update(
        (value) => value.copyWith(
          evidence: <RepairEvidence>[...value.evidence, ...accepted],
        ),
      );
    }
    if (rejection != null) {
      state = state.copyWith(errorMessage: rejection);
    }
  }

  String? _sizeError(RepairEvidence evidence) {
    final maxBytes = evidence.isVideo
        ? 100 * 1024 * 1024
        : evidence.isAudio
        ? 25 * 1024 * 1024
        : evidence.isImage
        ? 12 * 1024 * 1024
        : 15 * 1024 * 1024;
    if (evidence.byteSize <= 0) {
      return '${evidence.filename} is empty.';
    }
    if (evidence.byteSize > maxBytes) {
      return '${evidence.filename} is larger than the allowed size.';
    }
    return null;
  }

  void removeEvidence(String id) {
    final localPath = state.draft?.evidence
        .where((item) => item.id == id)
        .firstOrNull
        ?.localPath;
    update((draft) {
      final reordered = draft.evidence.where((item) => item.id != id).toList();
      return draft.copyWith(
        evidence: <RepairEvidence>[
          for (var index = 0; index < reordered.length; index++)
            reordered[index].copyWith(sortOrder: index),
        ],
      );
    });
    if (localPath != null) {
      unawaited(_mediaPicker.deleteLocal(localPath));
    }
  }

  void reorderEvidence(int oldIndex, int newIndex) {
    update((draft) {
      final items = [...draft.evidence];
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      return draft.copyWith(
        evidence: <RepairEvidence>[
          for (var index = 0; index < items.length; index++)
            items[index].copyWith(sortOrder: index),
        ],
      );
    });
  }

  Future<void> retryEvidence(String id) async {
    update(
      (draft) => draft.copyWith(
        evidence: [
          for (final item in draft.evidence)
            if (item.id == id)
              item.copyWith(
                uploadStatus: EvidenceUploadStatus.pending,
                clearFailureReason: true,
              )
            else
              item,
        ],
      ),
    );
    state = state.copyWith(noticeMessage: 'Upload queued for the next retry.');
  }

  Future<void> saveNow() async {
    _autosaveTimer?.cancel();
    final draft = state.draft;
    if (draft == null || draft.status != RepairDraftStatus.draft) {
      return;
    }
    state = state.copyWith(isSaving: true);
    try {
      await _repository.saveDraft(draft);
      state = state.copyWith(isSaving: false);
    } on Object catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'This change could not be saved on this device.',
      );
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () => unawaited(saveNow()));
  }

  Future<bool> submit() async {
    final draft = state.draft;
    if (draft == null) {
      return false;
    }
    final error = RepairRequestValidation.submissionError(draft);
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return false;
    }
    await saveNow();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );
    try {
      final id = await _repository.submit(
        draft,
        isOnline: state.isOnline,
        onEvidenceStatus: _setEvidenceStatus,
      );
      state = state.copyWith(
        draft: (state.draft ?? draft).copyWith(
          status: RepairDraftStatus.submitted,
        ),
        isSubmitting: false,
        submittedRequestId: id,
      );
      return true;
    } on RepairRequestFailure catch (failure) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      );
      return false;
    }
  }

  void _setEvidenceStatus(
    String evidenceId,
    EvidenceUploadStatus uploadStatus,
    String? failureReason,
  ) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(
      draft: draft.copyWith(
        evidence: [
          for (final item in draft.evidence)
            if (item.id == evidenceId)
              item.copyWith(
                uploadStatus: uploadStatus,
                failureReason: failureReason,
                clearFailureReason: failureReason == null,
              )
            else
              item,
        ],
      ),
    );
  }

  Future<void> startFreshDraft() async {
    final old = state.draft;
    final user = ref.read(authSessionControllerProvider).user;
    if (user == null) {
      return;
    }
    if (old != null && old.status == RepairDraftStatus.draft) {
      await _repository.discardDraft(old.id);
    }
    final draft = RepairRequestDraft.empty(
      id: _uuid.v4(),
      customerId: user.id,
      now: DateTime.now(),
    );
    await _repository.saveDraft(draft);
    state = RepairRequestWizardState(draft: draft, isLoading: false);
  }

  SymptomKind _kindForSuggested(String description) {
    final value = description.toLowerCase();
    if (value.contains('noise') || value.contains('buzz')) {
      return SymptomKind.heard;
    }
    if (value.contains('smell')) {
      return SymptomKind.smell;
    }
    if (value.contains('heat')) {
      return SymptomKind.heat;
    }
    if (value.contains('vibrat') || value.contains('wobble')) {
      return SymptomKind.vibration;
    }
    if (value.contains('warning')) {
      return SymptomKind.warningLight;
    }
    if (value.contains('error')) {
      return SymptomKind.errorCode;
    }
    if (value.contains('leak') || value.contains('damage')) {
      return SymptomKind.seen;
    }
    return SymptomKind.other;
  }
}

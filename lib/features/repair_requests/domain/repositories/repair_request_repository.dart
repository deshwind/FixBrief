import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';

typedef EvidenceStatusCallback =
    void Function(
      String evidenceId,
      EvidenceUploadStatus status,
      String? failureReason,
    );

abstract interface class RepairRequestRepository {
  Future<RepairRequestDraft?> loadActiveDraft(String customerId);

  Future<void> saveDraft(RepairRequestDraft draft);

  Future<void> discardDraft(String draftId);

  Future<String> submit(
    RepairRequestDraft draft, {
    required bool isOnline,
    EvidenceStatusCallback? onEvidenceStatus,
  });
}

class RepairRequestFailure implements Exception {
  const RepairRequestFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

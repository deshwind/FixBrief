import 'package:fixbrief/features/repair_requests/data/local/repair_draft_database.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/domain/repositories/repair_request_repository.dart';

class DemoRepairRequestRepository implements RepairRequestRepository {
  DemoRepairRequestRepository(this._database);

  final RepairDraftDatabase _database;

  @override
  Future<RepairRequestDraft?> loadActiveDraft(String customerId) {
    return _database.loadActiveDraft(customerId);
  }

  @override
  Future<void> saveDraft(RepairRequestDraft draft) {
    return _database.saveDraft(draft);
  }

  @override
  Future<void> discardDraft(String draftId) {
    return _database.deleteDraft(draftId);
  }

  @override
  Future<String> submit(
    RepairRequestDraft draft, {
    required bool isOnline,
    EvidenceStatusCallback? onEvidenceStatus,
  }) async {
    if (!isOnline) {
      throw const RepairRequestFailure(
        'You are offline. Your draft is safe and will not be submitted yet.',
      );
    }
    for (final evidence in draft.evidence) {
      onEvidenceStatus?.call(evidence.id, EvidenceUploadStatus.uploading, null);
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    for (final evidence in draft.evidence) {
      onEvidenceStatus?.call(evidence.id, EvidenceUploadStatus.ready, null);
    }
    await _database.saveDraft(
      draft.copyWith(status: RepairDraftStatus.submitted),
    );
    return draft.id;
  }
}

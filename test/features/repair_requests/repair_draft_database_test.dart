import 'package:drift/native.dart';
import 'package:fixbrief/features/repair_requests/data/local/repair_draft_database.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists and restores the latest unfinished draft offline', () async {
    final database = RepairDraftDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final draft =
        RepairRequestDraft.empty(
          id: 'draft-id',
          customerId: 'customer-id',
          now: DateTime(2026, 7, 17),
        ).copyWith(
          categorySlug: 'electrical',
          categoryLabel: 'Electrical',
          itemName: 'Kitchen socket',
          currentStep: 2,
        );

    await database.saveDraft(draft);
    final restored = await database.loadActiveDraft('customer-id');

    expect(restored, isNotNull);
    expect(restored!.id, 'draft-id');
    expect(restored.itemName, 'Kitchen socket');
    expect(restored.currentStep, 2);

    await database.saveDraft(
      restored.copyWith(status: RepairDraftStatus.submitted),
    );
    expect(await database.loadActiveDraft('customer-id'), isNull);
  });
}

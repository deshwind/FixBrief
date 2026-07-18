import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/domain/repair_request_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepairRequestDraft', () {
    test('round-trips all Stage 5 draft data', () {
      final now = DateTime(2026, 7, 17, 12, 30);
      final draft =
          RepairRequestDraft.empty(
            id: 'request-id',
            customerId: 'customer-id',
            now: now,
          ).copyWith(
            categorySlug: 'appliances',
            categoryLabel: 'Appliances',
            subcategory: 'Washing machine',
            itemName: 'Washing machine',
            brand: 'Example',
            model: 'WM100',
            problemDescription: 'It knocks loudly during every spin cycle.',
            symptoms: const <RepairSymptom>[
              RepairSymptom(
                id: 'symptom-id',
                kind: SymptomKind.heard,
                description: 'Loud knocking',
                source: SymptomSource.suggested,
              ),
            ],
            evidence: const <RepairEvidence>[
              RepairEvidence(
                id: 'media-id',
                kind: RepairEvidenceKind.image,
                localPath: '/private/photo.jpg',
                filename: 'photo.jpg',
                mimeType: 'image/jpeg',
                byteSize: 2048,
                sortOrder: 0,
              ),
            ],
            urgency: RepairUrgency.within3Days,
            approximateArea: 'Manchester M20',
            exactAddress: '10 Example Street, Manchester',
            budgetMinimum: 80,
            budgetMaximum: 200,
          );

      final restored = RepairRequestDraft.fromJson(draft.toJson());

      expect(restored.id, draft.id);
      expect(restored.categorySlug, 'appliances');
      expect(restored.symptoms.single.kind, SymptomKind.heard);
      expect(restored.evidence.single.mimeType, 'image/jpeg');
      expect(restored.urgency, RepairUrgency.within3Days);
      expect(restored.exactAddress, draft.exactAddress);
      expect(restored.budgetMaximum, 200);
    });

    test('requires a useful brief and private publishing location', () {
      final empty = RepairRequestDraft.empty(
        id: 'request-id',
        customerId: 'customer-id',
        now: DateTime(2026),
      );
      expect(
        RepairRequestValidation.submissionError(empty),
        'Choose a repair category.',
      );

      final complete = empty.copyWith(
        categorySlug: 'plumbing',
        categoryLabel: 'Plumbing',
        itemName: 'Kitchen tap',
        problemDescription: 'Water leaks from the base whenever it is used.',
        approximateArea: 'Leeds LS1',
        exactAddress: '12 Example Road, Leeds',
      );
      expect(RepairRequestValidation.submissionError(complete), isNull);
    });
  });
}

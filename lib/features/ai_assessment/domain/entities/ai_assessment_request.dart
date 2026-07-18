import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_assessment_request.freezed.dart';
part 'ai_assessment_request.g.dart';

@freezed
abstract class AiAssessmentRequest with _$AiAssessmentRequest {
  const factory AiAssessmentRequest({
    required String requestId,
    required String category,
    required String subcategory,
    required String itemName,
    required String brand,
    required String model,
    required String problemDescription,
    required String previousRepairs,
    required bool isStillUsable,
    required bool isWorsening,
    required List<String> symptoms,
    required List<String> evidenceKinds,
    @Default(<String, String>{}) Map<String, String> followUpAnswers,
  }) = _AiAssessmentRequest;

  factory AiAssessmentRequest.fromJson(Map<String, Object?> json) =>
      _$AiAssessmentRequestFromJson(json);
}

AiAssessmentRequest aiAssessmentRequestFromDraft(
  String requestId,
  RepairRequestDraft? draft,
) {
  if (draft == null || draft.id != requestId) {
    return AiAssessmentRequestPreview.preview(requestId);
  }
  return AiAssessmentRequest(
    requestId: requestId,
    category: draft.categoryLabel ?? draft.customCategory ?? 'Other',
    subcategory: draft.subcategory ?? '',
    itemName: draft.itemName,
    brand: draft.brand,
    model: draft.model,
    problemDescription: draft.problemDescription,
    previousRepairs: draft.previousRepairs,
    isStillUsable: draft.isStillUsable,
    isWorsening: draft.isWorsening,
    symptoms: draft.symptoms.map((item) => item.description).toList(),
    evidenceKinds: draft.evidence
        .map((item) => item.kind.databaseValue)
        .toList(),
  );
}

extension AiAssessmentRequestPreview on AiAssessmentRequest {
  static AiAssessmentRequest preview(String requestId) => AiAssessmentRequest(
    requestId: requestId,
    category: 'Appliances',
    subcategory: 'Washing machine',
    itemName: 'Washing machine',
    brand: '',
    model: '',
    problemDescription:
        'The washing machine makes a loud knocking sound and vibrates during the spin cycle.',
    previousRepairs: '',
    isStillUsable: true,
    isWorsening: true,
    symptoms: const <String>['Loud knocking', 'Strong vibration'],
    evidenceKinds: const <String>[],
  );
}

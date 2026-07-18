import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/domain/safety/ai_safety_rules_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAssessment', () {
    test('round-trips the structured response and validates it', () {
      final assessment = _assessment();

      final restored = AiAssessment.fromJson(assessment.toJson());

      expect(restored, assessment);
      expect(AiAssessmentValidator.validate(restored), same(restored));
      expect(restored.hasHighSafetyRisk, isFalse);
    });

    test('rejects a response that removes the uncertainty disclaimer', () {
      final invalid = _assessment().copyWith(disclaimer: 'Confirmed fault');

      expect(
        () => AiAssessmentValidator.validate(invalid),
        throwsA(isA<AiAssessmentFailure>()),
      );
    });
  });

  group('AiSafetyRulesEngine', () {
    test('independently detects a gas leak and forces stop-use advice', () {
      final request = AiAssessmentRequest(
        requestId: 'request-id',
        category: 'Heating',
        subcategory: 'Boiler',
        itemName: 'Boiler',
        brand: '',
        model: '',
        problemDescription:
            'There is a strong smell of gas and a hissing sound.',
        previousRepairs: '',
        isStillUsable: true,
        isWorsening: false,
        symptoms: const <String>[],
        evidenceKinds: const <String>[],
      );

      final finding = AiSafetyRulesEngine.evaluate(request);

      expect(finding.risk, AiSafetyRisk.critical);
      expect(finding.stopUsingItem, isTrue);
      expect(finding.warning, contains('Stop using the item'));
      expect(finding.categories, contains('Gas leak'));
    });
  });
}

AiAssessment _assessment() {
  return AiAssessment(
    id: 'assessment-id',
    requestId: 'request-id',
    version: 1,
    itemName: 'Washing machine',
    problemDescription: 'The appliance vibrates during its spin cycle.',
    problemSummary: 'The appliance vibrates during its spin cycle.',
    possibleFaultCategories: const <String>['Suspension'],
    possibleCauses: const <AiPossibleCause>[
      AiPossibleCause(
        id: 'cause-id',
        name: 'Unbalanced load',
        confidence: .62,
        reason: 'The reported vibration may relate to an uneven load.',
      ),
    ],
    urgency: AiAssessmentUrgency.medium,
    safetyRisk: AiSafetyRisk.low,
    stopUsingItem: false,
    safetyWarning: '',
    recommendedProfessional: 'Appliance repair specialist',
    recommendedSpecialisations: const <String>['Laundry appliances'],
    followUpQuestions: const <AiFollowUpQuestion>[
      AiFollowUpQuestion(
        id: 'question-id',
        question: 'Does this happen with every load?',
        isEssential: true,
      ),
    ],
    missingInformation: const <String>['Load size'],
    recommendedEvidence: const <String>['Short video from a safe distance'],
    inspectionRecommendation: 'Arrange a physical inspection.',
    repairBrief:
        'The customer reports vibration during the spin cycle. A professional should inspect the appliance.',
    generatedAt: DateTime.utc(2026, 7, 17),
  );
}

import 'dart:async';

import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/ai_assessment/domain/safety/ai_safety_rules_engine.dart';

class DemoAiAssessmentRepository implements AiAssessmentRepository {
  final Map<String, AiAssessment> _assessments = <String, AiAssessment>{};
  final Map<String, RepairBriefEdits> _briefs = <String, RepairBriefEdits>{};
  final Set<String> _published = <String>{};

  @override
  Future<AiAssessment> generate(
    AiAssessmentRequest request, {
    bool regenerate = false,
  }) async {
    final existing = _assessments[request.requestId];
    if (!regenerate && existing != null) {
      return existing;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1350));
    final assessment = _buildAssessment(
      request,
      version: (_assessments[request.requestId]?.version ?? 0) + 1,
    );
    _assessments[request.requestId] = assessment;
    return AiAssessmentValidator.validate(assessment);
  }

  @override
  Future<AiAssessment> answerFollowUpQuestions(
    AiAssessmentRequest request,
    Map<String, String> answers,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final assessment = _buildAssessment(
      request.copyWith(followUpAnswers: answers),
      version: (_assessments[request.requestId]?.version ?? 0) + 1,
      answeredQuestions: answers,
    );
    _assessments[request.requestId] = assessment;
    return AiAssessmentValidator.validate(assessment);
  }

  @override
  Future<void> saveRepairBrief(String requestId, RepairBriefEdits edits) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _briefs[requestId] = edits;
  }

  @override
  Future<void> publish(String requestId, RepairBriefEdits edits) async {
    await saveRepairBrief(requestId, edits);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _published.add(requestId);
  }

  AiAssessment _buildAssessment(
    AiAssessmentRequest request, {
    required int version,
    Map<String, String> answeredQuestions = const <String, String>{},
  }) {
    final safety = AiSafetyRulesEngine.evaluate(request);
    final category = request.category.toLowerCase();
    final problem = request.problemDescription.trim().isEmpty
        ? 'The item makes a loud knocking sound and vibrates during use.'
        : request.problemDescription.trim();
    final isVehicle = category.contains('vehicle') || category.contains('car');
    final isElectrical = category.contains('electrical');

    final possibleCauses = isVehicle
        ? <AiPossibleCause>[
            AiPossibleCause(
              id: '${request.requestId}-cause-1',
              name: 'Worn CV joint or wheel-area component',
              confidence: 0.62,
              reason:
                  'Clicking or vibration while turning may be associated with wear around the wheel or drivetrain.',
            ),
            AiPossibleCause(
              id: '${request.requestId}-cause-2',
              name: 'Steering or suspension wear',
              confidence: 0.34,
              reason:
                  'Movement and vibration may also relate to steering or suspension components.',
            ),
          ]
        : isElectrical
        ? <AiPossibleCause>[
            AiPossibleCause(
              id: '${request.requestId}-cause-1',
              name: 'Loose or damaged electrical connection',
              confidence: 0.56,
              reason:
                  'Intermittent electrical behaviour may be associated with a loose or damaged connection.',
            ),
            AiPossibleCause(
              id: '${request.requestId}-cause-2',
              name: 'Component or supply fault',
              confidence: 0.37,
              reason:
                  'The reported behaviour may also relate to a failed component or unstable supply.',
            ),
          ]
        : <AiPossibleCause>[
            AiPossibleCause(
              id: '${request.requestId}-cause-1',
              name: 'Unbalanced load or unstable installation',
              confidence: 0.66,
              reason:
                  'Knocking and strong vibration during a spin cycle may occur when a load or appliance is unbalanced.',
            ),
            AiPossibleCause(
              id: '${request.requestId}-cause-2',
              name: 'Worn suspension or drum support',
              confidence: 0.43,
              reason:
                  'Increasing movement may also be associated with wear in internal support components.',
            ),
          ];

    final questions = <AiFollowUpQuestion>[
      AiFollowUpQuestion(
        id: '${request.requestId}-question-1',
        question: isVehicle
            ? 'Does the sound become louder during full-lock turns?'
            : 'Does the problem happen with every load or only heavier loads?',
        isEssential: true,
        answer: answeredQuestions['${request.requestId}-question-1'] ?? '',
      ),
      AiFollowUpQuestion(
        id: '${request.requestId}-question-2',
        question: isVehicle
            ? 'Does the sound also occur while driving straight?'
            : 'Is the item level and stable when it is not running?',
        answer: answeredQuestions['${request.requestId}-question-2'] ?? '',
        isSkipped:
            answeredQuestions['${request.requestId}-question-2'] ==
            '__skipped__',
      ),
    ];
    final followUpSummary = answeredQuestions.entries
        .where(
          (entry) => entry.value != '__skipped__' && entry.value.isNotEmpty,
        )
        .map((entry) => entry.value)
        .join(' ');
    final risk = safety.risk == AiSafetyRisk.none
        ? (isVehicle ? AiSafetyRisk.moderate : AiSafetyRisk.low)
        : safety.risk;
    final stopUsing = safety.stopUsingItem;
    final urgency = stopUsing
        ? AiAssessmentUrgency.emergency
        : request.isWorsening
        ? AiAssessmentUrgency.medium
        : AiAssessmentUrgency.low;
    final professional = isVehicle
        ? 'Vehicle mechanic'
        : isElectrical
        ? 'Qualified electrician'
        : 'Appliance repair specialist';

    return AiAssessment(
      id: 'demo-${request.requestId}-$version',
      requestId: request.requestId,
      version: version,
      itemName: request.itemName,
      problemDescription: problem,
      problemSummary:
          '$problem${followUpSummary.isEmpty ? '' : ' Follow-up details: $followUpSummary'}',
      possibleFaultCategories: isVehicle
          ? const <String>['Steering', 'Suspension', 'Wheel assembly']
          : isElectrical
          ? const <String>['Electrical supply', 'Wiring', 'Component fault']
          : const <String>['Installation', 'Drum support', 'Suspension'],
      possibleCauses: possibleCauses,
      urgency: urgency,
      safetyRisk: risk,
      stopUsingItem: stopUsing,
      safetyWarning: safety.warning,
      recommendedProfessional: professional,
      recommendedSpecialisations: isVehicle
          ? const <String>['Steering', 'Suspension', 'Drivetrain']
          : isElectrical
          ? const <String>['Inspection', 'Testing', 'Fault finding']
          : const <String>['Laundry appliances', 'Diagnostics'],
      followUpQuestions: questions,
      missingInformation: answeredQuestions.isEmpty
          ? <String>[
              questions.first.question,
              if (!questions.last.isEssential) questions.last.question,
            ]
          : const <String>[],
      recommendedEvidence: isVehicle
          ? const <String>[
              'A short audio recording made while safely stationary nearby',
              'A photo of any warning lights',
            ]
          : const <String>[
              'A short video showing the movement from a safe distance',
              'A photo showing how the item is positioned',
            ],
      inspectionRecommendation:
          'Arrange a physical inspection before accepting a final repair price.',
      repairBrief:
          'The customer reports: $problem ${request.isWorsening ? 'The issue appears to be getting worse. ' : ''}'
          '${followUpSummary.isEmpty ? '' : 'Additional answers: $followUpSummary '}'
          'Possible causes may include the listed intake categories. $professional inspection is recommended before the exact fault or final price is confirmed.',
      disclaimer: aiAssessmentDisclaimer,
      generatedAt: DateTime.now().toUtc(),
    );
  }
}

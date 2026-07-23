import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/safety/ai_safety_rules_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiSafetyRulesEngine', () {
    test('escalates gas leaks as critical and stops further use', () {
      final finding = AiSafetyRulesEngine.evaluate(
        _request('There is a strong smell of gas and a hissing sound.'),
      );

      expect(finding.risk, AiSafetyRisk.critical);
      expect(finding.stopUsingItem, isTrue);
      expect(finding.categories, contains('Gas leak'));
      expect(finding.warning, contains('Do not attempt further testing'));
    });

    test('detects high-risk electrical hazards across symptom fields', () {
      final finding = AiSafetyRulesEngine.evaluate(
        _request(
          'The appliance stopped working.',
          symptoms: const [
            'I can see an exposed wire and water is leaking onto the socket.',
          ],
        ),
      );

      expect(finding.risk, AiSafetyRisk.high);
      expect(
        finding.categories,
        containsAll(<String>['Exposed electricity', 'Water near electricity']),
      );
      expect(finding.stopUsingItem, isTrue);
    });

    test('does not invent a warning for ordinary repair symptoms', () {
      final finding = AiSafetyRulesEngine.evaluate(
        _request('The washing machine vibrates only during the spin cycle.'),
      );

      expect(finding.risk, AiSafetyRisk.none);
      expect(finding.stopUsingItem, isFalse);
      expect(finding.warning, isEmpty);
      expect(finding.categories, isEmpty);
    });
  });
}

AiAssessmentRequest _request(
  String description, {
  List<String> symptoms = const <String>[],
}) {
  return AiAssessmentRequest(
    requestId: 'safety-test',
    category: 'Appliances',
    subcategory: 'Washing machine',
    itemName: 'Washing machine',
    brand: '',
    model: '',
    problemDescription: description,
    previousRepairs: '',
    isStillUsable: false,
    isWorsening: true,
    symptoms: symptoms,
    evidenceKinds: const <String>[],
  );
}

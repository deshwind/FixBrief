import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';

class AiSafetyFinding {
  const AiSafetyFinding({
    required this.risk,
    required this.stopUsingItem,
    required this.warning,
    required this.categories,
  });

  const AiSafetyFinding.none()
    : risk = AiSafetyRisk.none,
      stopUsingItem = false,
      warning = '',
      categories = const <String>[];

  final AiSafetyRisk risk;
  final bool stopUsingItem;
  final String warning;
  final List<String> categories;
}

abstract final class AiSafetyRulesEngine {
  static const _strongWarning =
      'Potential safety risk detected. Stop using the item and contact a '
      'qualified professional. Do not attempt further testing or repair.';

  static final Map<String, RegExp> _highRiskRules = <String, RegExp>{
    'Gas leak': RegExp(
      r'\b(gas leak|smell of gas|hissing gas)\b',
      caseSensitive: false,
    ),
    'Exposed electricity': RegExp(
      r'\b(exposed (wire|wiring)|live wire|electric shock|electrocut)\b',
      caseSensitive: false,
    ),
    'Electrical burning': RegExp(
      r'\b(burning (wire|electrical|plastic)|electrical burn|sparking)\b',
      caseSensitive: false,
    ),
    'Smoke or fire': RegExp(
      r'\b(smoke|smoking|fire|flame)\b',
      caseSensitive: false,
    ),
    'Severe overheating': RegExp(
      r'\b(overheat|extremely hot|too hot to touch)\b',
      caseSensitive: false,
    ),
    'Vehicle brakes': RegExp(
      r'\b(brake failure|brakes? not working|no brakes?|brake pedal.*floor)\b',
      caseSensitive: false,
    ),
    'Vehicle steering': RegExp(
      r'\b(cannot steer|steering failure|lost steering)\b',
      caseSensitive: false,
    ),
    'Fuel leak': RegExp(
      r'\b(fuel leak|petrol leak|diesel leak)\b',
      caseSensitive: false,
    ),
    'Structural damage': RegExp(
      r'\b(structural damage|collapsing|load.bearing crack|ceiling.*fall)\b',
      caseSensitive: false,
    ),
    'Chemical leak': RegExp(
      r'\b(chemical leak|acid leak|toxic spill)\b',
      caseSensitive: false,
    ),
    'Pressurised system': RegExp(
      r'\b(pressurised leak|pressure vessel|boiler pressure)\b',
      caseSensitive: false,
    ),
    'Water near electricity': RegExp(
      r'\b(water.*(socket|electric|wiring)|electric.*water)\b',
      caseSensitive: false,
    ),
    'Battery swelling': RegExp(
      r'\b(swollen battery|battery swelling|bulging battery)\b',
      caseSensitive: false,
    ),
    'Dangerous machinery': RegExp(
      r'\b(unguarded blade|machine.*starts itself|safety guard.*broken)\b',
      caseSensitive: false,
    ),
    'Sharp or unstable component': RegExp(
      r'\b(sharp edge|unstable component|hanging loose|could fall)\b',
      caseSensitive: false,
    ),
  };

  static AiSafetyFinding evaluate(AiAssessmentRequest request) {
    final input = <String>[
      request.problemDescription,
      request.previousRepairs,
      ...request.symptoms,
      ...request.followUpAnswers.values,
    ].join(' ');
    final matched = <String>[
      for (final rule in _highRiskRules.entries)
        if (rule.value.hasMatch(input)) rule.key,
    ];
    if (matched.isEmpty) {
      return const AiSafetyFinding.none();
    }
    final isCritical = matched.any(
      (category) =>
          category == 'Gas leak' ||
          category == 'Smoke or fire' ||
          category == 'Vehicle brakes',
    );
    return AiSafetyFinding(
      risk: isCritical ? AiSafetyRisk.critical : AiSafetyRisk.high,
      stopUsingItem: true,
      warning: _strongWarning,
      categories: matched,
    );
  }
}

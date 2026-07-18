import {
  DISCLAIMER,
  type ModelAssessment,
  type RepairRequestInput,
  type SafetyFinding,
  type SafetyRisk,
} from "./types.ts";

export const SAFETY_VERSION = "fixbrief-safety-v1";

const strongWarning =
  "Potential safety risk detected. Stop using the item and contact a qualified professional. Do not attempt further testing or repair.";

const rules: Array<{ category: string; risk: SafetyRisk; pattern: RegExp }> = [
  {
    category: "Gas leak",
    risk: "critical",
    pattern: /\b(gas leak|smell of gas|hissing gas)\b/i,
  },
  {
    category: "Exposed electricity",
    risk: "high",
    pattern: /\b(exposed (wire|wiring)|live wire|electric shock|electrocut)\b/i,
  },
  {
    category: "Electrical burning",
    risk: "high",
    pattern: /\b(electrical burn|burning (wire|wiring|plastic)|sparking)\b/i,
  },
  {
    category: "Smoke or fire",
    risk: "critical",
    pattern: /\b(smoke|smoking|fire|flame)\b/i,
  },
  {
    category: "Severe overheating",
    risk: "high",
    pattern: /\b(overheat|extremely hot|too hot to touch)\b/i,
  },
  {
    category: "Vehicle brakes",
    risk: "critical",
    pattern:
      /\b(brake failure|brakes? not working|no brakes?|brake pedal.{0,20}floor)\b/i,
  },
  {
    category: "Vehicle steering",
    risk: "high",
    pattern: /\b(cannot steer|steering failure|lost steering)\b/i,
  },
  {
    category: "Fuel leak",
    risk: "critical",
    pattern: /\b(fuel leak|petrol leak|diesel leak)\b/i,
  },
  {
    category: "Structural damage",
    risk: "high",
    pattern:
      /\b(structural damage|collapsing|load.?bearing crack|ceiling.{0,20}fall)\b/i,
  },
  {
    category: "Chemical leak",
    risk: "critical",
    pattern: /\b(chemical leak|acid leak|toxic spill)\b/i,
  },
  {
    category: "Pressurised system",
    risk: "high",
    pattern: /\b(pressurised leak|pressure vessel|boiler pressure)\b/i,
  },
  {
    category: "Water near electricity",
    risk: "critical",
    pattern: /\b(water.{0,30}(socket|electric|wiring)|electric.{0,30}water)\b/i,
  },
  {
    category: "Battery swelling",
    risk: "high",
    pattern: /\b(swollen battery|battery swelling|bulging battery)\b/i,
  },
  {
    category: "Dangerous machinery",
    risk: "high",
    pattern:
      /\b(unguarded blade|machine.{0,30}starts itself|safety guard.{0,20}broken)\b/i,
  },
  {
    category: "Sharp or unstable components",
    risk: "high",
    pattern: /\b(sharp edge|unstable component|hanging loose|could fall)\b/i,
  },
];

export function evaluateSafety(input: RepairRequestInput): SafetyFinding {
  const text = [
    input.problem_description,
    input.previous_repairs,
    ...input.symptoms.map((item) => item.description),
    ...input.follow_up_answers.map((item) => item.answer),
  ].join(" ");
  const matches = rules.filter((rule) => rule.pattern.test(text));
  if (matches.length === 0) {
    return {
      risk: "none",
      stop_using_item: false,
      warning: "",
      categories: [],
    };
  }
  const risk: SafetyRisk = matches.some((rule) => rule.risk === "critical")
    ? "critical"
    : "high";
  return {
    risk,
    stop_using_item: true,
    warning: strongWarning,
    categories: matches.map((rule) => rule.category),
  };
}

export function applySafetyRules(
  assessment: ModelAssessment,
  finding: SafetyFinding,
): ModelAssessment {
  const result = structuredClone(assessment);
  result.problem_summary = cautious(result.problem_summary);
  result.repair_brief = cautious(result.repair_brief);
  result.possible_causes = result.possible_causes.map((cause) => ({
    ...cause,
    name: cautious(cause.name),
    reason: cautious(cause.reason),
    confidence: Math.min(0.85, Math.max(0, cause.confidence)),
  }));
  result.disclaimer = DISCLAIMER;
  if (finding.stop_using_item) {
    result.safety_risk = finding.risk;
    result.stop_using_item = true;
    result.safety_warning = finding.warning;
    result.urgency = "emergency";
  } else if (
    result.safety_risk === "high" || result.safety_risk === "critical"
  ) {
    result.stop_using_item = true;
    result.safety_warning = result.safety_warning.trim() || strongWarning;
  }
  return result;
}

function cautious(value: string): string {
  return value
    .replace(/\bdefinitely\b/gi, "possibly")
    .replace(/\bcertainly\b/gi, "possibly")
    .replace(/\bconfirmed diagnosis\b/gi, "possible assessment")
    .replace(
      /\byou can safely continue using\b/gi,
      "a professional should advise whether to continue using",
    );
}

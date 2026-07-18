import { DISCLAIMER, type ModelAssessment } from "./types.ts";

export function validateAssessment(value: unknown): ModelAssessment {
  if (!isRecord(value)) throw new Error("Assessment must be an object.");
  string(value.problem_summary, "problem_summary", 1, 5000);
  stringArray(
    value.possible_fault_categories,
    "possible_fault_categories",
    8,
    120,
  );
  if (
    !Array.isArray(value.possible_causes) || value.possible_causes.length > 8
  ) {
    throw new Error("possible_causes is invalid.");
  }
  for (const cause of value.possible_causes) {
    if (!isRecord(cause)) throw new Error("A possible cause is invalid.");
    string(cause.name, "possible cause name", 1, 300);
    string(cause.reason, "possible cause reason", 1, 1000);
    if (
      typeof cause.confidence !== "number" || cause.confidence < 0 ||
      cause.confidence > 1
    ) {
      throw new Error("A possible cause confidence is invalid.");
    }
  }
  oneOf(value.urgency, "urgency", ["low", "medium", "high", "emergency"]);
  oneOf(value.safety_risk, "safety_risk", [
    "none",
    "low",
    "moderate",
    "high",
    "critical",
  ]);
  if (typeof value.stop_using_item !== "boolean") {
    throw new Error("stop_using_item is invalid.");
  }
  string(value.safety_warning, "safety_warning", 0, 1000);
  string(value.recommended_professional, "recommended_professional", 1, 200);
  stringArray(
    value.recommended_specialisations,
    "recommended_specialisations",
    8,
    120,
  );
  if (
    !Array.isArray(value.follow_up_questions) ||
    value.follow_up_questions.length > 8
  ) {
    throw new Error("follow_up_questions is invalid.");
  }
  for (const question of value.follow_up_questions) {
    if (!isRecord(question)) {
      throw new Error("A follow-up question is invalid.");
    }
    string(question.question, "follow-up question", 1, 1000);
    if (typeof question.is_essential !== "boolean") {
      throw new Error("is_essential is invalid.");
    }
  }
  stringArray(value.missing_information, "missing_information", 12, 300);
  stringArray(value.recommended_evidence, "recommended_evidence", 8, 300);
  string(value.inspection_recommendation, "inspection_recommendation", 1, 1000);
  string(value.repair_brief, "repair_brief", 20, 15000);
  if (value.disclaimer !== DISCLAIMER) {
    throw new Error("The disclaimer is invalid.");
  }
  return value as unknown as ModelAssessment;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function string(
  value: unknown,
  field: string,
  min: number,
  max: number,
): asserts value is string {
  if (typeof value !== "string" || value.length < min || value.length > max) {
    throw new Error(`${field} is invalid.`);
  }
}

function stringArray(
  value: unknown,
  field: string,
  maxItems: number,
  maxLength: number,
): asserts value is string[] {
  if (
    !Array.isArray(value) || value.length > maxItems ||
    value.some((item) =>
      typeof item !== "string" || item.length < 1 || item.length > maxLength
    )
  ) {
    throw new Error(`${field} is invalid.`);
  }
}

function oneOf(
  value: unknown,
  field: string,
  allowed: string[],
): asserts value is string {
  if (typeof value !== "string" || !allowed.includes(value)) {
    throw new Error(`${field} is invalid.`);
  }
}

import {
  DISCLAIMER,
  type ModelAssessment,
  type RepairRequestInput,
} from "./types.ts";

export function buildFallbackAssessment(
  input: RepairRequestInput,
): ModelAssessment {
  const description = input.problem_description.trim() ||
    "The customer has reported a problem with the item.";
  const category = input.category || "General repair";
  return {
    problem_summary: description,
    possible_fault_categories: [category],
    possible_causes: [{
      name: "Cause not yet established",
      confidence: 0.1,
      reason:
        "The available information is not enough to suggest a narrower possible cause safely.",
    }],
    urgency: input.is_still_usable ? "medium" : "high",
    safety_risk: "moderate",
    stop_using_item: !input.is_still_usable,
    safety_warning: input.is_still_usable
      ? "No specific high-risk condition was detected from the available information. Stop use if the condition changes or appears unsafe."
      : "Stop using the item until a qualified professional has inspected it.",
    recommended_professional: `${category} repair professional`,
    recommended_specialisations: [category, "Inspection", "Fault finding"],
    follow_up_questions: [{
      question: "What changes immediately before the problem starts?",
      is_essential: false,
    }],
    missing_information: [
      "A professional inspection is needed to narrow the possible cause",
    ],
    recommended_evidence: [
      "A clear photo or short recording captured from a safe distance",
    ],
    inspection_recommendation:
      "Arrange a physical inspection before accepting a final repair price.",
    repair_brief:
      `${description} The exact fault cannot be confirmed without physical inspection. A qualified professional should inspect the item.`,
    disclaimer: DISCLAIMER,
  };
}

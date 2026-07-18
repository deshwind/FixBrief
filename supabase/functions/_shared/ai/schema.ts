export const assessmentJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "problem_summary",
    "possible_fault_categories",
    "possible_causes",
    "urgency",
    "safety_risk",
    "stop_using_item",
    "safety_warning",
    "recommended_professional",
    "recommended_specialisations",
    "follow_up_questions",
    "missing_information",
    "recommended_evidence",
    "inspection_recommendation",
    "repair_brief",
    "disclaimer",
  ],
  properties: {
    problem_summary: { type: "string", minLength: 1, maxLength: 5000 },
    possible_fault_categories: {
      type: "array",
      maxItems: 8,
      items: { type: "string", minLength: 1, maxLength: 120 },
    },
    possible_causes: {
      type: "array",
      maxItems: 8,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "confidence", "reason"],
        properties: {
          name: { type: "string", minLength: 1, maxLength: 300 },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          reason: { type: "string", minLength: 1, maxLength: 1000 },
        },
      },
    },
    urgency: { type: "string", enum: ["low", "medium", "high", "emergency"] },
    safety_risk: {
      type: "string",
      enum: ["none", "low", "moderate", "high", "critical"],
    },
    stop_using_item: { type: "boolean" },
    safety_warning: { type: "string", maxLength: 1000 },
    recommended_professional: { type: "string", minLength: 1, maxLength: 200 },
    recommended_specialisations: {
      type: "array",
      maxItems: 8,
      items: { type: "string", minLength: 1, maxLength: 120 },
    },
    follow_up_questions: {
      type: "array",
      maxItems: 8,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["question", "is_essential"],
        properties: {
          question: { type: "string", minLength: 1, maxLength: 1000 },
          is_essential: { type: "boolean" },
        },
      },
    },
    missing_information: {
      type: "array",
      maxItems: 12,
      items: { type: "string", minLength: 1, maxLength: 300 },
    },
    recommended_evidence: {
      type: "array",
      maxItems: 8,
      items: { type: "string", minLength: 1, maxLength: 300 },
    },
    inspection_recommendation: {
      type: "string",
      minLength: 1,
      maxLength: 1000,
    },
    repair_brief: { type: "string", minLength: 20, maxLength: 15000 },
    disclaimer: {
      type: "string",
      enum: ["AI-assisted assessment — not a confirmed diagnosis."],
    },
  },
} as const;

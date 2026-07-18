export const DISCLAIMER = "AI-assisted assessment — not a confirmed diagnosis.";

export type AssessmentUrgency = "low" | "medium" | "high" | "emergency";
export type SafetyRisk = "none" | "low" | "moderate" | "high" | "critical";

export interface PossibleCause {
  name: string;
  confidence: number;
  reason: string;
}

export interface FollowUpQuestion {
  question: string;
  is_essential: boolean;
}

export interface ModelAssessment {
  problem_summary: string;
  possible_fault_categories: string[];
  possible_causes: PossibleCause[];
  urgency: AssessmentUrgency;
  safety_risk: SafetyRisk;
  stop_using_item: boolean;
  safety_warning: string;
  recommended_professional: string;
  recommended_specialisations: string[];
  follow_up_questions: FollowUpQuestion[];
  missing_information: string[];
  recommended_evidence: string[];
  inspection_recommendation: string;
  repair_brief: string;
  disclaimer: typeof DISCLAIMER;
}

export interface RepairRequestInput {
  id: string;
  status: string;
  category: string;
  subcategory: string;
  item_name: string;
  brand: string;
  model: string;
  approximate_age_years: number | null;
  previous_repairs: string;
  problem_description: string;
  is_still_usable: boolean;
  symptoms: Array<{ kind: string; description: string }>;
  evidence_counts: Record<string, number>;
  follow_up_answers: Array<{ question: string; answer: string }>;
}

export interface SafetyFinding {
  risk: SafetyRisk;
  stop_using_item: boolean;
  warning: string;
  categories: string[];
}

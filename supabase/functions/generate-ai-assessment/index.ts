import {
  createClient,
  type SupabaseClient,
} from "jsr:@supabase/supabase-js@2.110.7";
import { buildFallbackAssessment } from "../_shared/ai/fallback.ts";
import { OpenAiAssessmentService } from "../_shared/ai/openai.ts";
import { buildAssessmentPrompt, PROMPT_VERSION } from "../_shared/ai/prompt.ts";
import {
  applySafetyRules,
  evaluateSafety,
  SAFETY_VERSION,
} from "../_shared/ai/safety.ts";
import { validateAssessment } from "../_shared/ai/validation.ts";
import {
  DISCLAIMER,
  type ModelAssessment,
  type RepairRequestInput,
} from "../_shared/ai/types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };
const maxBodyBytes = 32_000;

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return errorResponse(405, "Method not allowed.");
  }
  const started = Date.now();
  let admin: SupabaseClient | null = null;
  let userId: string | null = null;
  let requestId: string | null = null;
  let operation = "unknown";
  let inputBytes = 0;
  try {
    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (contentLength > maxBodyBytes) {
      throw new HttpError(413, "The request is too large.");
    }
    const rawBody = await request.text();
    inputBytes = new TextEncoder().encode(rawBody).length;
    if (inputBytes > maxBodyBytes) {
      throw new HttpError(413, "The request is too large.");
    }
    const body = parseBody(rawBody);
    operation = requiredString(body.action, "action", 30);
    requestId = requiredUuid(body.request_id, "request_id");

    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const anonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    const authorization = request.headers.get("Authorization");
    if (!authorization) throw new HttpError(401, "Authentication is required.");
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth
      .getUser();
    if (authError || !authData.user) {
      throw new HttpError(401, "Your session has expired.");
    }
    userId = authData.user.id;
    admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const ownedRequest = await loadOwnedRequest(admin, requestId, userId);
    if (operation === "generate") {
      await enforceRateLimit(admin, userId);
      const regenerate = body.regenerate === true;
      if (!regenerate) {
        const existing = await loadLatestAssessment(admin, requestId);
        if (existing) return successResponse({ assessment: existing });
      }
      const assessment = await generateAndPersist(admin, ownedRequest, userId);
      await logUsage(
        admin,
        userId,
        requestId,
        operation,
        "success",
        inputBytes,
        started,
      );
      return successResponse({ assessment });
    }
    if (operation === "answer") {
      await enforceRateLimit(admin, userId);
      await saveAnswers(admin, requestId, body.answers);
      const refreshed = await loadOwnedRequest(admin, requestId, userId);
      const assessment = await generateAndPersist(admin, refreshed, userId);
      await logUsage(
        admin,
        userId,
        requestId,
        operation,
        "success",
        inputBytes,
        started,
      );
      return successResponse({ assessment });
    }
    if (operation === "save_brief") {
      await saveBriefEdits(admin, ownedRequest, body.edits);
      return successResponse({ saved: true });
    }
    if (operation === "publish") {
      await saveBriefEdits(admin, ownedRequest, body.edits);
      const { error } = await admin.from("repair_requests")
        .update({ status: "published" })
        .eq("id", requestId)
        .eq("customer_id", userId)
        .eq("status", "assessment_complete");
      if (error) {
        throw new HttpError(
          409,
          "The request could not be published in its current state.",
        );
      }
      return successResponse({ published: true });
    }
    throw new HttpError(400, "Unknown assessment action.");
  } catch (error) {
    if (admin && userId && requestId) {
      await logUsage(
        admin,
        userId,
        requestId,
        operation,
        "failed",
        inputBytes,
        started,
      );
    }
    if (error instanceof HttpError) {
      return errorResponse(error.status, error.message);
    }
    console.error("AI assessment failed", {
      operation,
      requestId,
      error: error instanceof Error ? error.message : "unknown",
    });
    return errorResponse(
      500,
      "The assessment could not be completed. Your request is safe.",
    );
  }
});

async function loadOwnedRequest(
  admin: SupabaseClient,
  requestId: string,
  userId: string,
): Promise<RepairRequestInput> {
  const { data: row, error } = await admin.from("repair_requests").select(
    "id,status,category_id,subcategory_id,item_name,brand,model,approximate_age_years,previous_repairs,problem_description",
  ).eq("id", requestId).eq("customer_id", userId).is("deleted_at", null)
    .maybeSingle();
  if (error || !row) throw new HttpError(404, "Repair request not found.");
  if (!["submitted", "assessment_complete"].includes(row.status)) {
    throw new HttpError(
      409,
      "Submit the repair request before starting its assessment.",
    );
  }
  const latestAssessment = await admin.from("ai_assessments").select("id")
    .eq("request_id", requestId).eq("validation_status", "valid")
    .order("version", { ascending: false }).limit(1).maybeSingle();
  if (latestAssessment.error) {
    throw new HttpError(500, "Assessment context could not be loaded.");
  }
  const [
    { data: category },
    { data: subcategory },
    symptomsResult,
    mediaResult,
    questionsResult,
  ] = await Promise.all([
    row.category_id
      ? admin.from("repair_categories").select("name").eq("id", row.category_id)
        .maybeSingle()
      : Promise.resolve({ data: null }),
    row.subcategory_id
      ? admin.from("repair_subcategories").select("name").eq(
        "id",
        row.subcategory_id,
      ).maybeSingle()
      : Promise.resolve({ data: null }),
    admin.from("repair_request_symptoms").select("kind,description")
      .eq("request_id", requestId).is("deleted_at", null).order("sort_order"),
    admin.from("repair_request_media").select("kind")
      .eq("request_id", requestId).eq("upload_status", "ready").is(
        "deleted_at",
        null,
      ),
    latestAssessment.data
      ? admin.from("ai_follow_up_questions").select(
        "question,answer,is_skipped,assessment_id",
      )
        .eq("assessment_id", latestAssessment.data.id)
        .not("answered_at", "is", null)
        .order("sort_order").limit(8)
      : Promise.resolve({ data: [], error: null }),
  ]);
  if (symptomsResult.error || mediaResult.error || questionsResult.error) {
    throw new HttpError(
      500,
      "The repair request could not be prepared for assessment.",
    );
  }
  const evidenceCounts: Record<string, number> = {};
  for (const media of mediaResult.data ?? []) {
    evidenceCounts[media.kind] = (evidenceCounts[media.kind] ?? 0) + 1;
  }
  return {
    id: row.id,
    status: row.status,
    category: category?.name ?? "Other",
    subcategory: subcategory?.name ?? "",
    item_name: row.item_name ?? "Item",
    brand: row.brand ?? "",
    model: row.model ?? "",
    approximate_age_years: row.approximate_age_years,
    previous_repairs: row.previous_repairs ?? "",
    problem_description: row.problem_description ?? "",
    is_still_usable: !/not usable|cannot use|stopped working/i.test(
      row.problem_description ?? "",
    ),
    symptoms: symptomsResult.data ?? [],
    evidence_counts: evidenceCounts,
    follow_up_answers: (questionsResult.data ?? [])
      .filter((question) => !question.is_skipped && question.answer)
      .map((question) => ({
        question: question.question,
        answer: question.answer,
      })),
  };
}

async function generateAndPersist(
  admin: SupabaseClient,
  input: RepairRequestInput,
  userId: string,
): Promise<Record<string, unknown>> {
  const prompt = buildAssessmentPrompt(input);
  if (new TextEncoder().encode(prompt).length > 24_000) {
    throw new HttpError(
      413,
      "The repair description is too large to assess safely.",
    );
  }
  const safety = evaluateSafety(input);
  let modelAssessment: ModelAssessment;
  let providerResponseId: string | null = null;
  let modelIdentifier = "fixbrief-conservative-fallback-v1";
  let isFallback = false;
  try {
    const apiKey = requiredEnvironment("OPENAI_API_KEY");
    const provider = new OpenAiAssessmentService(
      apiKey,
      Deno.env.get("OPENAI_MODEL") ?? "gpt-5.6-luna",
    );
    const result = await provider.assess(prompt, await sha256(userId));
    modelAssessment = result.assessment;
    providerResponseId = result.responseId;
    modelIdentifier = result.model;
  } catch (error) {
    console.error("AI provider unavailable; using conservative fallback", {
      requestId: input.id,
      error: error instanceof Error ? error.message : "unknown",
    });
    modelAssessment = buildFallbackAssessment(input);
    isFallback = true;
  }
  const assessment = applySafetyRules(
    validateAssessment(modelAssessment),
    safety,
  );
  const latest = await admin.from("ai_assessments").select("version")
    .eq("request_id", input.id).order("version", { ascending: false }).limit(1)
    .maybeSingle();
  if (latest.error) throw new HttpError(500, "Assessment versioning failed.");
  const version = (latest.data?.version ?? 0) + 1;
  const inputHash = await sha256(prompt);
  const topConfidence = Math.max(
    0,
    ...assessment.possible_causes.map((cause) => cause.confidence),
  );
  const confidence = topConfidence >= 0.67
    ? "high"
    : topConfidence >= 0.4
    ? "medium"
    : "low";
  const dbUrgency = {
    low: "flexible",
    medium: "within_3_days",
    high: "within_24_hours",
    emergency: "emergency",
  }[assessment.urgency];
  const insert = await admin.from("ai_assessments").insert({
    request_id: input.id,
    version,
    problem_summary: assessment.problem_summary,
    fault_categories: assessment.possible_fault_categories,
    confidence,
    urgency: dbUrgency,
    safety_risk: assessment.safety_risk,
    recommended_professional_type: assessment.recommended_professional,
    recommended_specialisations: assessment.recommended_specialisations,
    missing_information: assessment.missing_information,
    stop_using_item: assessment.stop_using_item,
    safety_warning: assessment.safety_warning || null,
    structured_repair_brief: assessment,
    suggested_evidence: assessment.recommended_evidence,
    suggested_inspection_type: assessment.inspection_recommendation,
    inspection_recommendation: assessment.inspection_recommendation,
    disclaimer: DISCLAIMER,
    input_hash: inputHash,
    model_identifier: modelIdentifier,
    prompt_version: PROMPT_VERSION,
    safety_version: SAFETY_VERSION,
    validation_status: "pending",
    is_fallback: isFallback,
    provider_response_id: providerResponseId,
  }).select("id").single();
  if (insert.error || !insert.data) {
    throw new HttpError(500, "The assessment could not be saved.");
  }
  const assessmentId = insert.data.id;
  try {
    if (assessment.possible_causes.length > 0) {
      const causes = await admin.from("ai_possible_causes").insert(
        assessment.possible_causes.map((cause, index) => ({
          assessment_id: assessmentId,
          cause: cause.name,
          confidence: cause.confidence,
          reasoning_summary: cause.reason,
          sort_order: index,
        })),
      );
      if (causes.error) throw causes.error;
    }
    if (assessment.follow_up_questions.length > 0) {
      const questions = await admin.from("ai_follow_up_questions").insert(
        assessment.follow_up_questions.map((question, index) => ({
          assessment_id: assessmentId,
          question: question.question,
          is_essential: question.is_essential,
          sort_order: index,
        })),
      );
      if (questions.error) throw questions.error;
    }
    const valid = await admin.from("ai_assessments")
      .update({ validation_status: "valid" }).eq("id", assessmentId);
    if (valid.error) throw valid.error;
    const requestUpdate = input.status === "submitted"
      ? {
        status: "assessment_complete",
        structured_brief: assessment.repair_brief,
      }
      : { structured_brief: assessment.repair_brief };
    const updated = await admin.from("repair_requests").update(requestUpdate)
      .eq("id", input.id);
    if (updated.error) throw updated.error;
  } catch (error) {
    await admin.from("ai_assessments").update({
      validation_status: "invalid",
      validation_errors: [{ code: "persistence_failed" }],
    }).eq("id", assessmentId);
    throw new HttpError(500, "The validated assessment could not be stored.");
  }
  const saved = await loadLatestAssessment(admin, input.id);
  if (!saved) {
    throw new HttpError(500, "The saved assessment could not be loaded.");
  }
  return saved;
}

async function loadLatestAssessment(
  admin: SupabaseClient,
  requestId: string,
): Promise<Record<string, unknown> | null> {
  const result = await admin.from("ai_assessments").select("*")
    .eq("request_id", requestId).eq("validation_status", "valid")
    .order("version", { ascending: false }).limit(1).maybeSingle();
  if (result.error) {
    throw new HttpError(500, "The assessment could not be loaded.");
  }
  if (!result.data) return null;
  const [causes, questions, repairRequest] = await Promise.all([
    admin.from("ai_possible_causes").select(
      "id,cause,confidence,reasoning_summary,hidden_from_customer",
    )
      .eq("assessment_id", result.data.id).order("sort_order"),
    admin.from("ai_follow_up_questions").select(
      "id,question,answer,is_essential,is_skipped",
    )
      .eq("assessment_id", result.data.id).order("sort_order"),
    admin.from("repair_requests").select(
      "item_name,problem_description,structured_brief",
    )
      .eq("id", requestId).maybeSingle(),
  ]);
  if (causes.error || questions.error || repairRequest.error) {
    throw new HttpError(500, "Assessment details could not be loaded.");
  }
  const structured = validateAssessment(result.data.structured_repair_brief);
  return {
    id: result.data.id,
    request_id: result.data.request_id,
    version: result.data.version,
    item_name: repairRequest.data?.item_name ?? "Item",
    problem_description: repairRequest.data?.problem_description ??
      structured.problem_summary,
    problem_summary: structured.problem_summary,
    possible_fault_categories: structured.possible_fault_categories,
    possible_causes: (causes.data ?? []).map((cause) => ({
      id: cause.id,
      name: cause.cause,
      confidence: cause.confidence,
      reason: cause.reasoning_summary ??
        "A possible relationship was found in the supplied information.",
      hidden: cause.hidden_from_customer,
    })),
    urgency: structured.urgency,
    safety_risk: result.data.safety_risk,
    stop_using_item: result.data.stop_using_item,
    safety_warning: result.data.safety_warning ?? "",
    recommended_professional: structured.recommended_professional,
    recommended_specialisations: result.data.recommended_specialisations,
    follow_up_questions: (questions.data ?? []).map((question) => ({
      id: question.id,
      question: question.question,
      is_essential: question.is_essential,
      answer: question.answer ?? "",
      is_skipped: question.is_skipped,
    })),
    missing_information: result.data.missing_information,
    recommended_evidence: result.data.suggested_evidence,
    inspection_recommendation: result.data.inspection_recommendation ??
      structured.inspection_recommendation,
    repair_brief: repairRequest.data?.structured_brief ??
      structured.repair_brief,
    disclaimer: result.data.disclaimer,
    is_fallback: result.data.is_fallback,
    generated_at: result.data.generated_at,
  };
}

async function saveAnswers(
  admin: SupabaseClient,
  requestId: string,
  value: unknown,
): Promise<void> {
  if (!Array.isArray(value) || value.length > 8) {
    throw new HttpError(400, "Follow-up answers are invalid.");
  }
  const latest = await admin.from("ai_assessments").select("id")
    .eq("request_id", requestId).eq("validation_status", "valid")
    .order("version", { ascending: false }).limit(1).maybeSingle();
  if (latest.error || !latest.data) {
    throw new HttpError(
      409,
      "Generate an assessment before answering questions.",
    );
  }
  const existing = await admin.from("ai_follow_up_questions").select(
    "id,is_essential",
  )
    .eq("assessment_id", latest.data.id);
  if (existing.error) {
    throw new HttpError(500, "Follow-up questions could not be loaded.");
  }
  const allowed = new Map(
    (existing.data ?? []).map((question) => [question.id, question]),
  );
  const answered = new Set<string>();
  for (const raw of value) {
    if (!isRecord(raw)) {
      throw new HttpError(400, "A follow-up answer is invalid.");
    }
    const questionId = requiredUuid(raw.question_id, "question_id");
    const answer = requiredString(raw.answer, "answer", 2000);
    if (!allowed.has(questionId) || answered.has(questionId)) {
      throw new HttpError(
        400,
        "A follow-up answer does not match this assessment.",
      );
    }
    answered.add(questionId);
    const skipped = answer === "__skipped__";
    if (skipped && allowed.get(questionId)?.is_essential) {
      throw new HttpError(400, "A required question cannot be skipped.");
    }
    const update = await admin.from("ai_follow_up_questions").update({
      answer: skipped ? null : answer,
      answer_source: skipped ? null : "typed",
      is_skipped: skipped,
      answered_at: new Date().toISOString(),
    }).eq("id", questionId).eq("assessment_id", latest.data.id);
    if (update.error) {
      throw new HttpError(500, "A follow-up answer could not be saved.");
    }
  }
  for (const question of allowed.values()) {
    if (question.is_essential && !answered.has(question.id)) {
      throw new HttpError(400, "Answer every required question.");
    }
  }
}

async function saveBriefEdits(
  admin: SupabaseClient,
  request: RepairRequestInput,
  value: unknown,
): Promise<void> {
  if (!isRecord(value)) {
    throw new HttpError(400, "Repair brief edits are invalid.");
  }
  const repairBrief = requiredString(
    value.repair_brief,
    "repair_brief",
    15_000,
  );
  const itemName = requiredString(value.item_name, "item_name", 160);
  const problemDescription = requiredString(
    value.problem_description,
    "problem_description",
    10_000,
  );
  if (
    repairBrief.length < 20 || itemName.length < 2 ||
    problemDescription.length < 10
  ) {
    throw new HttpError(400, "The edited repair brief needs more detail.");
  }
  const hiddenIds = Array.isArray(value.hidden_cause_ids)
    ? value.hidden_cause_ids.map((id) => requiredUuid(id, "hidden_cause_id"))
    : [];
  if (hiddenIds.length > 8) {
    throw new HttpError(400, "Too many cause edits were supplied.");
  }
  const latest = await admin.from("ai_assessments").select("id")
    .eq("request_id", request.id).eq("validation_status", "valid")
    .order("version", { ascending: false }).limit(1).maybeSingle();
  if (latest.error || !latest.data) {
    throw new HttpError(409, "A valid assessment is required.");
  }
  const reset = await admin.from("ai_possible_causes")
    .update({ hidden_from_customer: false }).eq(
      "assessment_id",
      latest.data.id,
    );
  if (reset.error) {
    throw new HttpError(500, "Cause selections could not be saved.");
  }
  if (hiddenIds.length > 0) {
    const hidden = await admin.from("ai_possible_causes").update({
      hidden_from_customer: true,
    })
      .eq("assessment_id", latest.data.id).in("id", hiddenIds);
    if (hidden.error) {
      throw new HttpError(500, "Cause selections could not be saved.");
    }
  }
  const update = await admin.from("repair_requests").update({
    structured_brief: repairBrief,
    item_name: itemName,
    problem_description: problemDescription,
  }).eq("id", request.id).in("status", ["assessment_complete"]);
  if (update.error) {
    throw new HttpError(
      409,
      "The brief cannot be edited in its current state.",
    );
  }
}

async function enforceRateLimit(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  const minuteAgo = new Date(Date.now() - 60_000).toISOString();
  const dayAgo = new Date(Date.now() - 86_400_000).toISOString();
  const [minute, day] = await Promise.all([
    admin.from("ai_usage_events").select("id", { count: "exact", head: true })
      .eq("user_id", userId).in("operation", ["generate", "answer"])
      .gte("created_at", minuteAgo),
    admin.from("ai_usage_events").select("id", { count: "exact", head: true })
      .eq("user_id", userId).in("operation", ["generate", "answer"])
      .gte("created_at", dayAgo),
  ]);
  if (minute.error || day.error) {
    throw new HttpError(500, "Rate limiting could not be checked.");
  }
  if ((minute.count ?? 0) >= 5 || (day.count ?? 0) >= 30) {
    throw new HttpError(
      429,
      "You have requested several assessments. Please wait before trying again.",
    );
  }
}

async function logUsage(
  admin: SupabaseClient,
  userId: string,
  requestId: string,
  operation: string,
  status: string,
  inputBytes: number,
  started: number,
): Promise<void> {
  const { error } = await admin.from("ai_usage_events").insert({
    user_id: userId,
    request_id: requestId,
    operation: operation.slice(0, 80),
    status,
    input_bytes: inputBytes,
    latency_milliseconds: Date.now() - started,
  });
  if (error) console.error("AI usage logging failed", { requestId, operation });
}

function parseBody(value: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(value);
    if (!isRecord(parsed)) throw new Error();
    return parsed;
  } catch {
    throw new HttpError(400, "The request body must be valid JSON.");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") {
    throw new HttpError(400, `${field} is required.`);
  }
  const clean = value.trim();
  if (!clean || clean.length > max) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  return clean;
}

function requiredUuid(value: unknown, field: string): string {
  const id = requiredString(value, field, 36);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(id)
  ) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  return id;
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function successResponse(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: jsonHeaders,
  });
}

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: jsonHeaders,
  });
}

# Stage 6: AI assessment

Stage 6 turns a submitted customer intake into a versioned, safety-checked
repair brief. It remains an **AI-assisted assessment, not a confirmed
diagnosis**. The request is not exposed to the repairer marketplace until the
customer reviews and explicitly publishes the final brief.

## Delivered customer journey

The submission confirmation now opens the assessment directly. The responsive
assessment experience includes:

1. An accessible animated processing orb with honest progress messages.
2. A problem summary, possible fault categories, restrained cause-confidence
   indicators, urgency, safety status, recommended professional and suggested
   evidence.
3. Required and optional follow-up questions, skip handling, voice dictation
   and assessment regeneration using the answers.
4. Editing for the item name, original problem description, final repair brief
   and customer removal of incorrect AI suggestions.
5. Save-without-publishing and explicit approve-and-publish actions.
6. Clear retry handling, durable server results and a visibly labelled
   conservative fallback when the AI provider is unavailable.

Serious warnings use a mostly opaque, high-contrast surface, a warning icon and
screen-reader text. They never rely on colour alone.

## Flutter architecture

Stage 6 adds strongly typed Freezed/json_serializable models for assessment
requests, assessments, possible causes, follow-up questions and customer brief
edits. `AiAssessmentRepository` separates demo and Supabase behavior, while the
Riverpod controller owns processing, question, review, save and publish state.

Demo mode runs a deterministic local assessment engine, including the same
independent keyword safety categories used by the backend. This makes the full
journey usable on the emulator without an AI key or hosted Supabase project.

Production invokes only the authenticated `generate-ai-assessment` Supabase
Edge Function. No provider key or service-role key is present in Flutter.

## Secure Edge Function

`supabase/functions/generate-ai-assessment` supports four authenticated
actions: `generate`, `answer`, `save_brief` and `publish`. It:

- verifies the JWT and request ownership;
- accepts only submitted/assessment-complete requests;
- enforces 32 KB request and 24 KB prompt limits;
- excludes exact addresses, account identity and media filenames/content;
- redacts email addresses, phone numbers and street-like addresses found in
  customer text;
- treats all customer text as untrusted prompt data;
- requests strict JSON Schema output through the OpenAI Responses API;
- validates the returned JSON again before storage;
- applies a separate deterministic safety rules engine after model output;
- retries transient provider failures with a 25-second per-attempt timeout;
- falls back to a conservative, low-confidence brief if the provider fails;
- limits users to five generation/answer operations per minute and 30 per day;
- records timing/status metrics without raw customer text;
- saves immutable assessment versions and server-owned causes/questions; and
- changes `submitted -> assessment_complete -> published` only at the correct
  points in the customer journey.

The provider request uses `store: false` and a SHA-256, privacy-preserving
`safety_identifier`. The default model can be overridden server-side with
`OPENAI_MODEL`.

## Safety rules

The independent rules cover gas leaks, exposed electricity, electrical
burning, smoke/fire, severe overheating, vehicle brakes/steering, fuel leaks,
structural damage, chemical leaks, pressurised systems, water near electricity,
battery swelling, dangerous machinery and sharp/unstable components.

Any high or critical match forces `stop_using_item`, a strong warning and
emergency urgency, regardless of what the model returned. Database constraints
also prevent a high/critical assessment from being stored without stop-use
advice and a warning.

## Database addition

`20260717110000_stage6_ai_assessment.sql` adds audit-friendly provider/fallback
metadata, recommended specialisations, the exact disclaimer constraint,
high-risk safety consistency and indexes for valid-latest assessment retrieval
and rate-limit checks. AI writes remain server-only under the Stage 4 RLS
baseline.

## Server configuration and deployment

Set secrets only in Supabase, never in Flutter configuration:

```powershell
npx --yes supabase@latest secrets set OPENAI_API_KEY=your-server-key
npx --yes supabase@latest secrets set OPENAI_MODEL=gpt-5.6-luna
npx --yes supabase@latest functions deploy generate-ai-assessment
```

For local function development, place server secrets in an ignored Supabase
environment file and pass it to `supabase functions serve`. Do not commit that
file.

## Failure behavior

- Invalid ownership, lifecycle or input receives a bounded 4xx response.
- Rate limits receive a clear 429 response.
- A provider outage produces a conservative, visibly limited assessment rather
  than inventing detailed causes.
- Failed persistence marks the pending assessment invalid; only validated
  snapshots are client-readable.
- Flutter retries one transient invocation, then keeps the request safe and
  offers an explicit retry.
- Publishing never occurs automatically.

## Verification

The Flutter verification suite covers structured JSON round-trip/validation,
disclaimer rejection, independent critical gas-risk detection and the complete
customer journey through follow-up answers, regeneration, brief review and
publishing. On this workstation, the completed Stage 6 build passed:

- `flutter analyze` with no issues;
- all 16 Flutter tests;
- Deno formatting and type-checking for the Edge Function;
- parsing all 12 SQL migrations and hydrating 38 PL/pgSQL functions;
- a debug Android APK build and installation on the Android 15/API 35 emulator;
- a manual emulator journey from assessment generation through follow-up
  regeneration, brief review and publishing; and
- a focused final device-log check with no error-priority entries from the app
  process.

The final emulator confirmation screenshot is available locally at
`build/stage6-published.png`.

Local Supabase runtime and pgTAP checks still require Docker Desktop. Run the
commands in the Stage 4 handoff before deploying the migration to a hosted
project.

## Stage 7 boundary

Stage 7 owns marketplace matching, repairer request discovery, privacy-safe
customer information and repairer profiles. Stage 6 stops when the customer has
published an approved brief.

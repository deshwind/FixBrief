# Stage 4 — Database and security

## Delivery status

Stage 4 is code-complete. The workspace now contains an ordered Supabase
migration baseline, PostgreSQL enums and tables, transactional invariants,
client RPCs, indexes, RLS on every public table, eight Stage 4 private storage buckets,
storage policies, deterministic local seed data, privacy-safe marketplace
projections, scoped Realtime publication, and pgTAP tests.

Stage 5 is now implemented and adds a ninth private bucket for PDF/text repair
documents; see the Stage 5 handoff for that additive migration.

The migrations pass PostgreSQL 17 SQL parsing and embedded PL/pgSQL-body
parsing. They have not yet been executed against a local Supabase stack because
Docker Desktop is not installed/running on this workstation. Run the local
verification commands below before applying the baseline to any hosted project.

## Migration order

| Migration | Purpose |
|---|---|
| `20260717090000_extensions_and_enums.sql` | Private schema, PostGIS, pgcrypto, trigram search, lifecycle/domain enums |
| `20260717090100_core_profiles_and_catalog.sql` | Profiles, role subtypes, categories, specialisations, certifications, service coverage, availability, audit/idempotency |
| `20260717090200_repair_requests_and_ai.sql` | Requests, exact-location separation, symptoms, evidence metadata, versioned AI snapshots |
| `20260717090300_marketplace_jobs_and_messaging.sql` | Quotes, jobs, history, appointments, conversations, messages, reviews, notifications, trust/safety |
| `20260717090400_invariants_and_triggers.sql` | Updated timestamps, immutable fields, transition maps, quote totals, history, review/rating checks |
| `20260717090500_secure_rpc_functions.sql` | Role/onboarding contract, contact authorization, quote acceptance, controlled job status |
| `20260717090600_row_level_security.sql` | Explicit grants and complete public-table RLS policies |
| `20260717090700_private_storage.sql` | Bucket restrictions and relationship-aware storage object policies |
| `20260717090800_marketplace_views_and_automation.sql` | Safe projections/matching, verification, metrics, notifications, Realtime |

All files are in `supabase/migrations`. Supabase applies them in filename order.

## Stage 4 file manifest

| Path | Placement and purpose |
|---|---|
| `supabase/config.toml` | Committed local Supabase/Auth configuration |
| `supabase/migrations/20260717090000_extensions_and_enums.sql` | Migration 1 |
| `supabase/migrations/20260717090100_core_profiles_and_catalog.sql` | Migration 2 |
| `supabase/migrations/20260717090200_repair_requests_and_ai.sql` | Migration 3 |
| `supabase/migrations/20260717090300_marketplace_jobs_and_messaging.sql` | Migration 4 |
| `supabase/migrations/20260717090400_invariants_and_triggers.sql` | Migration 5 |
| `supabase/migrations/20260717090500_secure_rpc_functions.sql` | Migration 6 |
| `supabase/migrations/20260717090600_row_level_security.sql` | Migration 7 |
| `supabase/migrations/20260717090700_private_storage.sql` | Migration 8 |
| `supabase/migrations/20260717090800_marketplace_views_and_automation.sql` | Migration 9 |
| `supabase/seed.sql` | Synthetic, deterministic local seed dataset |
| `supabase/tests/database/000_schema.test.sql` | pgTAP schema/security test |
| `supabase/tests/database/001_invariants.test.sql` | pgTAP derived-data/invariant test |
| `supabase/tests/database/002_rls.test.sql` | pgTAP role-permission matrix |
| `lib/features/onboarding/data/repositories/supabase_onboarding_repository.dart` | Aligns contact enum and separate avatar/logo buckets |
| `android/app/src/debug/AndroidManifest.xml` | Debug-only local HTTP access to Supabase on `10.0.2.2` |
| `docs/stage-4-database-security.md` | This implementation/deployment handoff |
| `docs/stage-3-authentication-onboarding.md` | Updated Stage 3 contract status |
| `README.md` | Updated project status and database commands |

## Data model

The 28 tables explicitly requested in the product specification are included:

- `profiles`, `customer_profiles`, `repairer_profiles`
- `repair_categories`, `repair_subcategories`
- `repairer_specialisations`, `repairer_certifications`, `service_areas`
- `repair_requests`, `repair_request_symptoms`, `repair_request_media`
- `ai_assessments`, `ai_possible_causes`, `ai_follow_up_questions`
- `quotes`, `quote_items`
- `jobs`, `job_status_history`
- `conversations`, `conversation_participants`, `messages`
- `reviews`, `notifications`, `saved_repairers`
- `reports`, `blocked_users`, `availability_slots`, `appointments`

Four supporting tables enforce the architecture and privacy requirements:

- `repair_request_private_locations` keeps exact addresses out of marketplace
  rows.
- `idempotency_keys` prevents duplicate transactional retries.
- `audit_events` records security-sensitive state changes without evidence
  bodies.
- `ai_usage_events` provides server-side rate/latency metadata without raw
  customer text.

## Server-enforced invariants

- New Auth users receive an idempotent, roleless `profiles` row.
- `claim_role` accepts exactly `customer` or `repairer`, requires verified
  email, locks the profile, and can run only once.
- Direct changes to role, onboarding/account status, repairer verification,
  marketplace metrics, and certification verification are blocked.
- Customer onboarding becomes `approved`; repairer onboarding becomes
  `submitted` and verification remains a separate trusted-backend action.
- Repair-request, quote, and job transitions use explicit allowlists.
- Quote totals are always derived from fee ranges and active line items.
- Accepting a quote locks the request/quote, rejects competing quotes, creates
  one job, authorizes the conversation, stores an idempotency result, and writes
  an audit event in one transaction.
- Job changes append immutable timeline history.
- Customers and repairers have separate allowed job-status actions; completion
  cannot be set through a direct table update.
- Reviews require a completed job, exact participant direction, unique author
  per job, and bounded ratings. Repairer averages/counts are derived.
- Quote, message, job, and review events create deduplicated in-app
  notifications.

## Client-callable RPCs

| Function | Caller and purpose |
|---|---|
| `claim_role(text)` | Verified authenticated user; one-time role claim used by Stage 3 |
| `claim_user_role(app_user_role)` | Typed compatibility wrapper |
| `complete_customer_onboarding(jsonb)` | Customer; validates and atomically completes profile |
| `submit_repairer_onboarding(jsonb)` | Repairer; validates business data and submits for review |
| `authorise_contact(uuid, uuid)` | Related customer/repairer after quote or job authorization |
| `accept_quote(uuid, text)` | Request owner; atomic and idempotent acceptance |
| `set_job_status(uuid, job_status, text)` | Job participant; role-specific controlled transitions |
| `get_own_repairer_profile()` | Repairer; private self-only profile fields |
| `get_matching_requests(...)` | Verified repairer; privacy-safe eligible request feed |
| `get_matching_repairers(...)` | Authenticated user; safe verified-repairer projection |

`set_repairer_verification(...)` is granted only to `service_role`. A service
role key must never be compiled into Flutter.

## RLS strategy

Every public table has RLS enabled and forced. Grants are explicit; the project
does not rely on legacy Data API auto-exposure.

- Anonymous users can read only active categories and subcategories.
- Customers can read/update their profile, create their requests, edit/delete
  owned drafts, and access quotes/jobs/conversations that belong to them.
- Repairers can edit their own business records, see only eligible published
  requests, manage only their active quotes, and access assigned jobs and
  conversations.
- Exact customer locations are separate and become readable by a repairer only
  after accepted-job or released-appointment authorization.
- AI and evidence rows require request ownership, marketplace eligibility with
  evidence sharing, or an assigned job.
- Conversations and messages require active membership; blocks are enforced by
  both RLS helpers and the message invariant.
- Reviews are immutable user submissions. Customer-to-repairer reviews are
  marketplace-readable; customer reviews written by repairers remain limited to
  participants.
- Notifications, saves, blocks, and reports are owner scoped.
- Audit and AI-usage tables have no client grants or policies.

`public_repairer_profiles` and `marketplace_repair_requests` are
`security_invoker` views that structurally omit raw contact details, business
address, precise customer location, and private certification evidence.

## Private storage

| Bucket | Limit | Allowed content |
|---|---:|---|
| `profile-images` | 5 MiB | JPEG, PNG, WebP |
| `business-logos` | 5 MiB | JPEG, PNG, WebP |
| `repair-request-images` | 12 MiB | JPEG, PNG, WebP, HEIC |
| `repair-request-videos` | 100 MiB | MP4, QuickTime |
| `repair-request-audio` | 25 MiB | M4A/AAC, MP3, WAV |
| `message-attachments` | 25 MiB | Approved image, PDF, text, and audio MIME types |
| `certifications` | 15 MiB | PDF, JPEG, PNG |
| `review-media` | 10 MiB | JPEG, PNG, WebP |

All buckets are private. Object names begin with the authenticated user's UUID.
Request/conversation/review IDs occupy the next path segment where relevant.
Reads repeat the database relationship checks; knowing an object path does not
grant access. The normal Supabase Storage API can create short-lived signed URLs
only after the object's SELECT policy succeeds.

Bucket limits validate declared upload size/MIME. Production still needs an
asynchronous trusted scanner/transcoder to verify file signatures, duration,
dimensions, and malware status before evidence is marked `ready`.

## Seed data

`supabase/seed.sql` contains synthetic local data only:

- all 23 top-level repair categories and representative subcategories;
- two customers and three verified repair businesses;
- vehicle clicking-noise, washing-machine vibration, leaking-pipe,
  laptop-overheating, bicycle-brake, phone-charging, and furniture-damage
  requests;
- cautious validated AI snapshots and possible causes;
- provisional quotes, authorized conversations/messages, one completed job,
  and an eligible review.

Local test account password: `FixBriefDemo123!`

The `.test` email domains and synthetic UUIDs are deliberate. Never use
`--include-seed` against production.

## Local setup and verification

Prerequisites are Node/npm, Supabase CLI, and Docker Desktop (or another
Docker-compatible runtime). The CLI can run project-scoped through `npx`:

```powershell
cd C:\Users\User\Desktop\RepairQuote
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

Expected local endpoints include API `http://127.0.0.1:54321`, Studio
`http://127.0.0.1:54323`, and Mailpit `http://127.0.0.1:54324`.

Run Flutter against local Supabase with the local publishable/anon key printed
by `supabase status`:

```powershell
C:\src\flutter\bin\flutter.bat run -d emulator-5554 `
  --dart-define=APP_ENV=development `
  --dart-define=AUTH_DEMO_MODE=false `
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 `
  --dart-define=SUPABASE_ANON_KEY=<local-client-key>
```

Android uses `10.0.2.2` to reach the Windows host. The local Auth configuration
already enables email confirmation, a 12-character mixed-case/digit password
policy, and both `fixbrief://auth-callback/...` URLs.

Official references:

- [Supabase local development and migrations](https://supabase.com/docs/guides/local-development/overview)
- [Database testing and linting](https://supabase.com/docs/guides/local-development/cli/testing-and-linting)
- [Row-Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Private Storage bucket access](https://supabase.com/docs/guides/storage/buckets/fundamentals)
- [Database seeding](https://supabase.com/docs/guides/local-development/seeding-your-database)

## Hosted development/staging deployment

Do not push until `db reset`, pgTAP, and lint all pass locally. If the hosted
project already has dashboard-created tables, first capture and reconcile its
schema instead of overwriting it.

```powershell
npx --yes supabase@latest login
npx --yes supabase@latest link --project-ref <development-project-ref>
npx --yes supabase@latest migration list
npx --yes supabase@latest db push --dry-run
npx --yes supabase@latest db push
```

Apply the exact reviewed migrations to development, then staging, then
production through CI. Do not reset a linked production database and do not
include synthetic seed data in production.

Manual hosted-project checks:

1. Confirm the remote PostgreSQL major version matches `supabase/config.toml`.
2. Confirm email/password Auth and both native redirect URLs from Stage 3.
3. Configure production SMTP and Auth rate limits/password policy.
4. Verify all nine buckets remain private after the additive Stage 5 migration.
5. Verify only `messages`, `notifications`, `appointments`, and
   `job_status_history` were added to Realtime.
6. Keep service-role/database credentials in CI or trusted backend secret
   storage, never Flutter configuration.
7. Run the role-matrix tests against development/staging before promotion.

## Tests

| Test file | Coverage |
|---|---|
| `000_schema.test.sql` | Tables, RLS enforcement, buckets, RPCs, grants, storage policies |
| `001_invariants.test.sql` | Quote totals, ratings, completed-job metrics, history, request automation |
| `002_rls.test.sql` | Anonymous, customer, and repairer visibility using JWT impersonation |

The Flutter regression suite remains separate and currently passes all 13 tests.

## Verification completed on this workstation

- PostgreSQL 17 top-level parser: all migrations, tests, and seed pass
- Embedded PL/pgSQL parser: all 37 function bodies pass
- `dart format lib test`: clean
- `flutter analyze`: no issues
- `flutter test`: 9 passed
- `supabase db reset --local`: blocked before execution because the Docker
  engine is not installed/running

## Known limitations

- Runtime migration, seed, pgTAP, and `plpgsql_check` lint results remain pending
  until Docker Desktop is installed and the local Supabase stack runs.
- This is a fresh-project baseline. Existing hosted schema changes must be
  pulled and reconciled before deployment.
- Onboarding currently stores typed location/address text. Geocoding the
  business/service centre and customer approximate area is required before
  strict distance matching can be relied upon.
- File malware scanning, MIME magic-byte verification, transcoding, abandoned
  upload cleanup, and signed-URL expiry choices require trusted backend/Edge
  Function work in their feature stages.
- Repairer verification and moderation have secure database functions but no
  staff UI/workflow yet.
- Realtime publication is prepared; Stage 9 implements the Flutter messaging
  client and typing-presence channel.

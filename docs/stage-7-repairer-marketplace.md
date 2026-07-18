# Stage 7 — Repairer marketplace

Stage 7 connects a customer-approved, published repair brief with eligible
repair professionals. It adds explainable server-side ranking, a live repairer
dashboard, request discovery and filters, privacy-safe request details, and
public-safe repairer profiles.

## Delivered Flutter structure

The feature is split into domain, data, state, presentation, and reusable
widgets under `lib/features/repairer_marketplace`:

- `domain/entities/marketplace_models.dart` defines filter, request, detail,
  assessment, profile, service-area, and dashboard contracts.
- `domain/repositories/repairer_marketplace_repository.dart` defines the
  marketplace boundary and user-safe failures.
- `data/repositories/demo_repairer_marketplace_repository.dart` supplies a
  deterministic six-request marketplace for local demo and tests.
- `data/repositories/supabase_repairer_marketplace_repository.dart` calls only
  Stage 7 RPC projections and creates short-lived evidence/logo URLs.
- `presentation/controllers` owns dashboard loading, debounced search, filter
  application, sorting, refresh, and recoverable error state.
- `presentation/screens/matching_requests_screen.dart` provides search,
  category, urgency, distance, mobile/collection and sort controls.
- `presentation/screens/marketplace_request_detail_screen.dart` shows the
  approved brief, eligible evidence, AI caveats, safety state and service needs
  without customer identity or precise location.
- `presentation/screens/repairer_profile_screen.dart` shows verified business
  identity, performance, specialisations, qualifications, approximate service
  coverage, availability and service capabilities.
- `presentation/widgets` contains the shared request card and repairer
  marketplace navigation.

The Stage 2 repairer-dashboard prototype is now backed by repository data. New
routes are:

- `/repairer/dashboard`
- `/repairer/requests`
- `/repairer/requests/:requestId`
- `/repairers/:repairerId` (`me` resolves to the signed-in repairer)

## Matching rules

`get_ranked_marketplace_requests` first applies hard eligibility rules:

- active, verified and marketplace-visible repairer account;
- category and compatible subcategory specialisation;
- service radius or active service-area coverage;
- mobile and collection capability when requested;
- emergency capability for emergency requests;
- no active unavailability exception for the preferred date;
- no customer/repairer block; and
- a published marketplace request state.

Eligible requests receive a bounded score using exact specialisation,
distance, availability, rating, response rate, urgency and requested service
fit. The API returns short, explainable reasons with each score. Repairers can
sort by best match, nearest, newest or urgency.

The score prioritises discovery only. It is not a diagnosis, price prediction,
guarantee of availability, or permission to contact the customer outside the
controlled marketplace.

## Privacy boundary

Before quote acceptance or a confirmed inspection, the Stage 7 API never
returns:

- customer ID, name, phone number or email;
- exact address or exact coordinates;
- private customer-profile rows;
- repairer private phone/email or precise business coordinates; or
- original evidence filenames.

Only an approximate area and calculated distance are returned. Free-text
marketplace fields receive defence-in-depth email, phone and street-pattern
redaction. Evidence payloads contain opaque storage paths only for eligible
repairers; Flutter converts those paths into five-minute signed URLs.

The existing private-location RLS remains authoritative. Exact customer
location becomes accessible only through an accepted job or an explicitly
confirmed and released inspection appointment.

## Database migration and seed data

`supabase/migrations/20260717120000_stage7_repairer_marketplace.sql` adds:

- `private.marketplace_safe_text`;
- availability- and emergency-aware marketplace eligibility;
- `public.get_ranked_marketplace_requests`;
- `public.get_marketplace_request_detail`;
- `public.get_repairer_marketplace_profile`; and
- `public.get_repairer_marketplace_summary`.

All public RPCs are revoked from `anon` and granted only to `authenticated`.
Each security-definer RPC validates the authenticated role and applies its own
row/eligibility checks before returning an explicit safe projection.

`supabase/seed.sql` now includes realistic repairer ratings, response/acceptance
metrics, completed-job history and recurring availability. The added pgTAP file
`supabase/tests/database/003_marketplace.test.sql` covers RPC presence, grants,
redaction, matching eligibility, safe request/profile projections, dashboard
counters and customer exclusion.

## Environment and deployment

Stage 7 adds no Flutter secrets or environment variables. It uses the existing
client-safe values:

- `APP_ENV`
- `AUTH_DEMO_MODE`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

For a hosted environment, apply migrations only after local database tests:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
npx --yes supabase@latest db push --linked
```

Do not expose the service-role key in Flutter. Repairer verification remains a
trusted server/admin action through the Stage 4 verification function.

## Run the demo

```powershell
flutter run -d emulator-5554 `
  --dart-define=APP_ENV=development `
  --dart-define=AUTH_DEMO_MODE=true `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=stage-7-demo
```

Create or sign in to a demo account, choose **I am a repair professional**, and
submit the business-onboarding form. Demo repairers are allowed into the app
with a submitted profile so the deterministic marketplace can be reviewed.

## Verification

Stage 7 tests cover model parsing, combined repository filters, score ordering,
the address/identity privacy contract and a widget journey through dashboard,
matching requests, request detail and business profile.

On this workstation, the completed Stage 7 build passed:

- `flutter analyze` with no issues;
- all 22 Flutter tests;
- PostgreSQL parser validation of all 12 migrations, all four database tests,
  and `seed.sql` (55 function definitions found);
- a debug Android APK build and installation on Android 15/API 35;
- a manual repairer journey through onboarding, dashboard, ranked requests,
  privacy-safe request detail, AI/evidence review and business profile; and
- a focused device-log check with no error-priority entries from the FixBrief
  app process.

The final marketplace screenshot is available locally at
`build/stage7-marketplace.png`.

Local Supabase execution and pgTAP still require Docker Desktop, which is not
installed on this workstation. PostgreSQL parser validation is used as a
non-runtime syntax check, but it does not replace `db reset`, pgTAP or `db lint`
before hosted deployment.

## Stage 8 boundary

Stage 7 discovers eligible requests and displays a **Prepare a provisional
quote** action. Stage 8 owns quote creation/editing/withdrawal, totals,
expiration, comparison, acceptance and provisional-estimate warnings. No quote
is created automatically in Stage 7.

# Stage 8 handoff: provisional quotes

Stage 8 completes the provisional quote workflow for repair professionals and
customers. It covers quote creation, editing, withdrawal, calculated totals,
comparison, acceptance, expiration, and the mandatory provisional-estimate
warning.

## Delivered Flutter journeys

Repair professionals can:

- open **Prepare or edit provisional quote** from an eligible marketplace
  request;
- enter inspection and call-out fees, labour/parts/other minimum and maximum
  ranges, and see a live total;
- set earliest availability, repair duration, collection/mobile service,
  warranty, expiry, comments, assumptions, and exclusions;
- save a private draft, submit it, edit it before acceptance, or withdraw it;
  and
- review all lifecycle states from the repairer **Quotes** navigation tab.

Customers can:

- open quote comparison from the active repair card or Requests navigation;
- compare estimated range, inspection fee, rating, review count, completed
  jobs, distance, availability, warranty, response rate, qualifications, and
  verification;
- see an explained **Strong overall fit** recommendation that is deliberately
  not based on cheapest price alone;
- inspect each repairer's privacy-safe public business profile; and
- accept one available quote after a confirmation step repeats the provisional
  warning and explains that a job will be created.

Routes added in Stage 8:

- `/repairer/requests/:requestId/quote`
- `/repairer/quotes`
- `/customer/requests/:requestId/quotes`

The public `/repairers/:repairerId` route is now available to customer
accounts while `/repairer/...` remains repairer-only.

Every quote surface displays the exact warning:

> **This is a provisional estimate. The final cost may change after physical inspection.**

## Architecture

The `lib/features/quotes` feature uses the same domain/data/presentation
boundary as the rest of FixBrief:

- `domain/entities/quote_models.dart` owns lifecycle, input, total, comparison,
  expiry, and warning models;
- `domain/repositories/quote_repository.dart` defines the role-neutral quote
  contract;
- `data/repositories/demo_quote_repository.dart` supplies deterministic mutable
  Stage 8 state for emulator and widget tests;
- `data/repositories/supabase_quote_repository.dart` maps only to controlled
  RPCs and ordinary-language failures; and
- `presentation` contains role-specific screens, providers, and the shared
  warning component.

Demo mode begins with three vehicle estimates. The strongest overall fit has a
better trust/service combination than the cheapest quote, which makes the
recommendation rule visible and testable. Repairer-created demo quotes persist
for the lifetime of the repository provider.

## Database migration

`supabase/migrations/20260717130000_stage8_quotes.sql` builds on the Stage 4
`quotes`, `quote_items`, `jobs`, idempotency, trigger, and RLS foundation.

Authenticated RPCs:

- `get_repairer_quote(uuid)`
- `get_repairer_quotes()`
- `save_quote_draft(uuid, uuid, jsonb)`
- `submit_quote(uuid)`
- `withdraw_quote(uuid)`
- `get_customer_quote_comparison(uuid)`
- the existing atomic `accept_quote(uuid, text)`

Server behavior:

- monetary and range inputs are validated as non-negative minor units;
- quote totals continue to be calculated by database triggers, not trusted
  from the client;
- only an eligible verified repairer can create a quote for a marketplace
  request;
- submitted quotes require a non-zero estimate, availability, and future
  expiry;
- stale submitted quotes are transitioned to `expired` when quote RPCs run;
- submission moves an eligible request to `quotes_received`;
- withdrawal removes the estimate from customer availability;
- acceptance locks and selects one quote, rejects competing submissions, moves
  the request to `quote_accepted`, creates exactly one job, and uses the
  existing idempotency key protection; and
- audit events record submission, withdrawal, and acceptance.

All Stage 8 public RPCs are revoked from `anon` and granted to
`authenticated`. Security-definer functions validate the signed-in role and
resource ownership. Helper functions are not executable by client roles.

## Privacy and comparison safety

Customer base-table RLS now excludes repairer drafts and withdrawn quotes.
Customers receive only submitted lifecycle states for requests they own.

The comparison RPC returns a fixed safe projection. It may use precise
locations internally to calculate distance, but it does not return repairer
coordinates, business address, phone, email, or customer private data.

The overall-fit score considers rating, completed work, verification, warranty,
availability, response rate, qualifications, and quote-accuracy history.
Recommendation reasons are returned with the quote. Price is shown for
comparison but is not used to label the cheapest estimate as best.

## Seed and tests

`supabase/seed.sql` now supplies three active estimates for one customer-owned
vehicle request, with deliberately different pricing, availability, warranty,
and trust characteristics.

`supabase/tests/database/004_quotes.test.sql` covers:

- RPC presence and grants;
- repairer quote scoping;
- server-calculated totals;
- customer comparison count;
- omission of private repairer fields;
- explained non-cheapest recommendation behavior; and
- atomic acceptance/job creation.

Flutter tests cover input totals, edit/submit/withdraw transitions, expiry,
non-cheapest recommendations, single-quote acceptance, and both narrow-phone
quote surfaces.

## Run the demo

```powershell
flutter run -d emulator-5554 `
  --dart-define=APP_ENV=development `
  --dart-define=AUTH_DEMO_MODE=true `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=stage-8-demo
```

Repairer journey:

1. Sign in with a password of at least 12 characters.
2. Choose **I am a repair professional** and complete onboarding.
3. Open **Requests**, select the Ford Focus request, then open the quote form.
4. Review the prefilled transparent range and submit it.
5. Use the **Quotes** tab to edit or withdraw an active estimate.

Customer journey:

1. Sign out, sign in again, choose **I need a repair**, and complete onboarding.
2. Open the active Ford Focus repair or the **Requests** destination.
3. Compare the three estimates, open a repairer profile, and accept one quote.

Demo identity and quote data are in-memory. Signing out resets onboarding, so
the two roles can be reviewed without separate backend accounts.

## Verification and deployment

On this workstation, the completed Stage 8 source passed:

- `flutter analyze` with no issues;
- all 29 Flutter tests; and
- PostgreSQL parser validation of all 13 migrations, all five database tests,
  and `seed.sql` (65 function definitions found);
- a debug APK build and installation on Android 15/API 35;
- a manual repairer journey through marketplace request, quote creation, live
  totals, submission, and editable submitted state;
- a manual customer journey through comparison, explained overall-fit
  recommendation, repairer metrics, confirmation, acceptance, job creation,
  and competing-quote rejection; and
- an accepted/disabled-state renderer check with no error-priority entries from
  the FixBrief app process.

The final accepted-quote screenshot is available locally at
`build/stage8-quotes.png`.

Before hosted deployment, install and start Docker Desktop, then run:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
npx --yes supabase@latest db push --linked
```

Docker Desktop is not installed on this workstation, so local Supabase reset,
pgTAP, RLS runtime checks, and database lint have not run. PostgreSQL parser
validation is a syntax check and does not replace those deployment gates.

## Stage 9 boundary

Stage 8 creates the accepted job and authorizes the selected quote. Stage 9
owns realtime conversations, messages, attachments, read states, appointment
suggestions, appointment confirmation, and inspection booking. Quote
acceptance does not automatically send a message or book an appointment.

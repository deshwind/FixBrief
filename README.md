# FixBrief

FixBrief is a mobile repair marketplace that turns a customer's plain-language
description and evidence into an **AI-assisted fault assessment**, then connects
the customer with suitable repair professionals for provisional quotes.

> **AI-assisted assessment — not a confirmed diagnosis.** A qualified
> professional should inspect the item. The exact fault cannot be confirmed
> without physical inspection.

## Current delivery status

Stages 1–8 are complete. The workspace contains the Flutter architecture,
Liquid Glass design system, customer and repairer prototypes, Supabase client
bootstrap, email/password authentication, password recovery, email
verification, role selection, role-specific onboarding, protected routes, the
complete Supabase migration/RLS/storage/seed baseline, and the customer
repair-request wizard with offline drafts, voice/audio input, private evidence,
review, secure submission, AI-assisted assessment processing, independent
safety rules, targeted follow-up questions, repair-brief editing and
customer-controlled publishing, explainable marketplace matching, a live
repairer dashboard, request search and filters, privacy-safe request details,
verified repairer profiles, provisional quote creation/editing/withdrawal,
server-calculated ranges, expiry, explained quote comparison, and atomic
customer acceptance.

Detailed handoffs:

- [`docs/stage-1-architecture.md`](docs/stage-1-architecture.md)
- [`docs/stage-2-design-system.md`](docs/stage-2-design-system.md)
- [`docs/stage-3-authentication-onboarding.md`](docs/stage-3-authentication-onboarding.md)
- [`docs/stage-4-database-security.md`](docs/stage-4-database-security.md)
- [`docs/stage-5-customer-repair-request.md`](docs/stage-5-customer-repair-request.md)
- [`docs/stage-6-ai-assessment.md`](docs/stage-6-ai-assessment.md)
- [`docs/stage-7-repairer-marketplace.md`](docs/stage-7-repairer-marketplace.md)
- [`docs/stage-8-quotes.md`](docs/stage-8-quotes.md)

Stage 9 messaging and appointments have not started. Local migration/pgTAP execution still
requires Docker Desktop on this workstation.

## Quick start: local demo

Flutter is installed at `C:\src\flutter`. In a new PowerShell window:

```powershell
cd C:\Users\User\Desktop\RepairQuote
flutter pub get
flutter run -d emulator-5554 `
  --dart-define=APP_ENV=development `
  --dart-define=AUTH_DEMO_MODE=true `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=stage-8-demo
```

Demo mode keeps account identity data in memory, persists unfinished repair
drafts locally, simulates request submission, and runs the full deterministic
assessment/follow-up/publish journey, a deterministic repairer marketplace,
and both sides of the provisional quote workflow.
It is rejected automatically when `APP_ENV=production`.

## Quick start: Supabase

```powershell
Copy-Item config\env.example.json config\env.dev.json
# Replace the Supabase placeholders and leave AUTH_DEMO_MODE false.
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run --dart-define-from-file=config/env.dev.json
```

If the current terminal has not picked up the updated `PATH`, use
`C:\src\flutter\bin\flutter.bat` and `C:\src\flutter\bin\dart.bat`.

Only client-safe configuration belongs in `config/env.dev.json`. Never put an
AI key or Supabase service-role key in the Flutter client.

## Supabase database verification

After installing and starting Docker Desktop:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

Do not push the migrations to a hosted project until those checks pass. See the
Stage 4 handoff for deployment and seed-data precautions.

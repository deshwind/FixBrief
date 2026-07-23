# FixBrief testing and Supabase verification

## Local Flutter quality gate

Run from the repository root:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test --coverage
```

The suite covers validation, authentication, immutable roles, offline draft
persistence, media-service boundaries, AI JSON validation, independent safety
rules, repair-request submission, marketplace privacy, quotes, messaging,
appointments, jobs, reviews, notifications, settings, and accessibility.

Mocks in `test/support/mock_services.dart` isolate:

- Supabase database and storage
- authentication and onboarding repositories
- AI generation
- connectivity and geolocation
- media picking, speech input, and audio recording
- repair-request persistence and upload orchestration

## Android integration journey

Start an Android emulator, confirm its identifier with `flutter devices`, then:

```powershell
flutter test integration_test\customer_release_journey_test.dart `
  -d emulator-5554
```

This signs in through demo authentication, claims the customer role, completes
onboarding, opens notifications, marks them read, enters Settings, and requests
a data export. It deliberately avoids live Supabase and store credentials.

Before a production candidate, repeat the journey with a staging Supabase
project and manually exercise:

1. Email verification and password recovery links.
2. Both customer and repairer onboarding.
3. Every evidence type and the permission-denied path.
4. Offline draft restoration and reconnection submission.
5. AI timeout, invalid JSON, fallback, and high-risk warnings.
6. Quote expiry and concurrent quote acceptance.
7. Participant-only messaging, blocking, and reporting.
8. Job completion and reciprocal reviews.
9. Export/deletion processing by the production workers.

## Supabase pgTAP

Docker must be running. The official Supabase CLI executes each pgTAP file in
its own rolled-back transaction.

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning --fail-on error
npx --yes supabase@latest stop --no-backup
```

The database tests are under `supabase/tests/database`. Never run `db reset`
against production. Before a hosted deployment:

```powershell
npx --yes supabase@latest link --project-ref YOUR_STAGING_PROJECT_REF
npx --yes supabase@latest db push --dry-run
npx --yes supabase@latest db push
npx --yes supabase@latest migration list
```

Deploy and smoke-test staging first. Production migrations require a backup,
an approved change window, and a rollback decision recorded in the release.

References:

- https://supabase.com/docs/reference/cli/supabase-test-db
- https://supabase.com/docs/reference/cli/supabase-db-lint
- https://supabase.com/docs/reference/cli/supabase-db-push

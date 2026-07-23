# Stage 12: testing and deployment

Stage 12 completes the twelve-stage implementation with automated release
coverage, service mocks, environment validation, platform release hardening,
CI quality gates, and publication runbooks.

## Added

- Unit coverage for environment rules, authentication, immutable roles, and AI
  safety decisions.
- Reusable mocks for Supabase, storage, connectivity, location, AI, media,
  speech, audio, authentication, onboarding, and request repositories.
- An Android integration journey covering authentication through settings and
  export.
- Android upload-key/CI signing with no debug-key release fallback, R8 resource
  shrinking, a cleartext-disabled release manifest, and a signed-AAB workflow.
- iOS release metadata plus an app privacy manifest included in Runner.
- Development, staging, and production environment templates and a validation
  command.
- Flutter, Android integration, and Supabase CI jobs.
- Supabase testing, Android/iOS release, environment, production, privacy, and
  store publication instructions.

## Commands

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test --coverage
flutter test integration_test\customer_release_journey_test.dart `
  -d emulator-5554
```

For local Supabase:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning --fail-on error
```

Generate ignored production configuration from
`config/env.production.example.json`, validate it, then use the platform guides
under `docs/release`.

## Manual steps and limitations

- Docker is required to execute the local database and pgTAP suite.
- iOS compilation/signing requires macOS, Xcode, an Apple team, and App Store
  Connect access.
- Android release signing requires a private upload keystore.
- This workstation still reports Android SDK licences awaiting the developer's
  review via `flutter doctor --android-licenses`.
- No hosted Supabase project, signing key, store account, legal approval, or
  production secret was available in this workspace, so nothing was pushed or
  published externally.
- Data-export/account-deletion background processors and device push delivery
  require production infrastructure before launch.
- Placeholder legal screens must be replaced with lawyer-approved public
  documents before store submission.

The codebase can produce tested release candidates, but public publication is
blocked until every applicable unchecked item in `docs/release/checklists.md`
is completed by the accountable owner.

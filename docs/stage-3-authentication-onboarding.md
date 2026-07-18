# Stage 3 — Authentication and onboarding

## Delivery status

Stage 3 is complete. It adds the Supabase client boundary, email/password
authentication, secure session persistence, recovery and verification deep
links, role selection, customer and repairer onboarding, protected routes, and
a development-only in-memory demo path.

The Stage 4 database schema, RPC bodies, RLS, private storage buckets, policies,
and seed data are now implemented in `supabase/`. See
`docs/stage-4-database-security.md` for validation and deployment requirements.

## Included journeys

- Splash and session restoration
- Welcome, registration, login, and sign-out
- Email verification and resend
- Forgot-password request and new-password screen
- One-time customer or repairer role selection
- Customer profile onboarding, including optional profile image
- Repairer business onboarding, including optional logo, categories,
  specialisations, credentials, service details, and availability
- Role-aware customer and repairer destinations
- Route guards for signed-out, unverified, roleless, and incomplete accounts
- Friendly domain errors without exposing raw Supabase messages

The redirect sequence is:

```text
bootstrap
  -> signed out: welcome/login
  -> unverified: email verification
  -> no role: role selection
  -> incomplete profile: matching onboarding screen
  -> complete customer: customer home
  -> submitted/approved repairer: repairer dashboard
```

Cross-role URLs are rejected. A customer cannot enter repairer routes and a
repairer cannot enter customer routes. `returnTo` accepts only bounded internal
paths and rejects authorities and protocol-relative URLs.

## Implementation map

| Area | Location |
|---|---|
| Environment and Supabase bootstrap | `lib/core/config`, `lib/core/services`, `lib/app/bootstrap.dart` |
| Encrypted session and PKCE storage | `lib/core/storage/secure_auth_storage.dart` |
| Auth domain and repositories | `lib/features/authentication/domain`, `lib/features/authentication/data` |
| Auth state orchestration | `lib/features/authentication/presentation/controllers` |
| Auth screens | `lib/features/authentication/presentation/screens` |
| Onboarding domain and repositories | `lib/features/onboarding/domain`, `lib/features/onboarding/data` |
| Onboarding screens | `lib/features/onboarding/presentation/screens` |
| Protected routing | `lib/core/routing/app_router.dart` |
| Android deep link | `android/app/src/main/AndroidManifest.xml` |
| iOS deep link | `ios/Runner/Info.plist` |
| Environment template | `config/env.example.json` |

## Run modes

### Development demo

Demo mode is for UI development and automated tests when a live backend is not
available:

```powershell
C:\src\flutter\bin\flutter.bat run -d emulator-5554 `
  --dart-define=APP_ENV=development `
  --dart-define=AUTH_DEMO_MODE=true `
  --dart-define=SUPABASE_URL=https://example.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=stage-3-demo
```

Use any valid email. Registration validation requires at least 12 characters
with uppercase, lowercase, and a number. The verification button simulates the
email callback. Demo state is in memory and is cleared when the app process is
restarted. The app refuses to start if demo auth is enabled in production.

### Live Supabase authentication

Copy `config/env.example.json` to a non-committed environment file, set
`AUTH_DEMO_MODE` to `false`, and add the project URL and client-safe publishable
or legacy anon key. A service-role key must never be compiled into the app.

```powershell
C:\src\flutter\bin\flutter.bat run `
  --dart-define-from-file=config/env.dev.json
```

Supabase is initialized with PKCE. Auth sessions and the PKCE verifier are
stored through `flutter_secure_storage` rather than ordinary preferences.

## Supabase dashboard setup

Before testing live email authentication:

1. Enable the Email provider and email confirmation in Authentication.
2. In Authentication URL Configuration, add both redirect URLs:
   - `fixbrief://auth-callback/verify-email`
   - `fixbrief://auth-callback/reset-password`
3. Ensure the confirmation and recovery email templates use the generated
   confirmation URL.
4. Configure production SMTP, appropriate send limits, and the project password
   policy before a public release.
5. Put only the project URL and client-safe publishable/anon key in the mobile
   environment file.

The Android and iOS hosts already register `fixbrief://auth-callback/...`.
Supabase Flutter handles auth callbacks from the native deep link.

Relevant official references:

- [Initialize Supabase Flutter](https://supabase.com/docs/reference/dart/initializing)
- [Flutter authentication tutorial](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Native mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)
- [Redirect URL configuration](https://supabase.com/docs/guides/auth/redirect-urls)

## Stage 4 backend contract

The live onboarding adapter targets the following server-owned contract, now
implemented atomically by the Stage 4 migrations:

- `profiles` exposes `role` and `onboarding_status` for the authenticated user.
- `claim_role(selected_role)` records exactly `customer` or `repairer` once.
- `complete_customer_onboarding(profile_data)` validates and writes the
  customer profile, then moves it to `approved`.
- `submit_repairer_onboarding(profile_data)` validates and writes the repairer
  profile, then moves it to `submitted` for later verification.
- Private `profile-images` and `business-logos` buckets store objects under the
  authenticated user's UUID.

Role and onboarding authority must live in protected database rows. Do not
authorize from user-editable auth metadata. RPC functions must derive the user
from `auth.uid()`, enforce one-time role assignment, validate all JSON fields,
and use RLS and storage policies to prevent cross-account access.

Live role selection/onboarding works after the Stage 4 migrations are applied to
the configured Supabase project. Do not recreate the contract with ad-hoc
dashboard tables.

## Verification completed

- Code generation: successful
- `dart format lib test`: clean
- `flutter analyze`: no issues
- `flutter test`: 9 tests passed
- Android debug APK: built successfully
- Android emulator: installed and launched on `Medium_Phone_API_35`
- Device UI: welcome and registration routes verified
- Device logs: no fatal exception, unhandled Flutter exception, or
  `E/flutter` entry during the checked journey

Generated APK:

`build/app/outputs/flutter-apk/app-debug.apk`

## Known tooling note

The Android build currently carries a scoped compatibility configuration for
plugins that still apply the Kotlin Gradle Plugin under Flutter's built-in
Kotlin migration. The build succeeds, but those plugins should be upgraded when
compatible releases are available.

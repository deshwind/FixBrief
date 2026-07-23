# Environment configuration

Flutter receives client-safe configuration through compile-time Dart defines.
No service-role, database password, signing password, or AI provider key may be
included in the app bundle.

## Client variables

| Key | Required | Meaning |
| --- | --- | --- |
| `APP_ENV` | Yes | `development`, `staging`, or `production` |
| `AUTH_DEMO_MODE` | Yes | Must be `false` outside local demo builds |
| `SUPABASE_URL` | Yes | HTTPS project URL; local HTTP is development-only |
| `SUPABASE_PUBLISHABLE_KEY` | Yes | Client-safe Supabase publishable key |

`SUPABASE_ANON_KEY` remains a temporary compatibility alias. New files should
use `SUPABASE_PUBLISHABLE_KEY`.

Templates:

- `config/env.example.json`
- `config/env.staging.example.json`
- `config/env.production.example.json`

Create ignored local files and replace every placeholder:

```powershell
Copy-Item config\env.example.json config\env.dev.json
Copy-Item config\env.staging.example.json config\env.staging.json
Copy-Item config\env.production.example.json config\env.production.json
```

Validate before any build:

```powershell
dart run tool\validate_environment.dart config\env.production.json
```

Build with one environment only:

```powershell
flutter run --dart-define-from-file=config\env.dev.json
flutter build apk --debug --dart-define-from-file=config\env.staging.json
flutter build appbundle --release `
  --dart-define-from-file=config\env.production.json
```

Production validation rejects demo authentication, HTTP, known placeholder
projects, missing keys, and placeholder keys. Values in `--dart-define` are
compiled into the client and must not be treated as secrets.

## Server-only secrets

Set these only in the relevant managed service:

- AI provider key: Supabase Edge Function secret.
- Supabase service-role key: trusted backend jobs only.
- Database password: secret manager and deployment tooling only.
- Android keystore passwords: CI environment or local `key.properties`.
- App Store Connect and Play credentials: protected CI environments.

Rotate credentials after accidental exposure. Never fix an exposure by merely
removing the latest commit; revoke the credential first.

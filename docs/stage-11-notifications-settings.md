# Stage 11 - notifications and settings

Stage 11 adds the shared notification inbox, role-aware deep links, persistent
appearance and accessibility preferences, notification delivery preferences,
privacy request structures, blocked-user management, and safe account deletion
scheduling.

## Delivered Flutter flow

- realtime-style in-app notification inbox for customers and repairers;
- unread badges, read state, mark-all-read, refresh, empty, loading, and error
  states;
- notification types for quotes, messages, appointments, jobs, reviews, quote
  expiry, and repairer matches;
- validated internal deep links with role checks and route normalization;
- shared Profile destination with notifications, settings, history/jobs,
  support, and sign-out actions;
- theme selection using system, light, or dark mode;
- full, reduced, and minimal visual-effect modes;
- persistent reduce-transparency and reduce-motion controls;
- push, email, message, quote, appointment, job, and matching-request
  preferences;
- data export requests with idempotent pending state;
- 14-day account deletion scheduling and cancellation structure;
- blocked-user list and unblock confirmation;
- help/support, privacy-policy, and terms screens;
- legal placeholders explicitly marked for professional review;
- encrypted local storage for appearance preferences;
- deterministic role-aware demo data.

Feature code is under `lib/features/notifications/` and
`lib/features/settings/`. Shared routes include `/notifications`, `/profile`,
`/settings`, `/settings/blocked-users`, `/help`, `/legal/privacy`, and
`/legal/terms`.

## Database and security boundary

Migration `20260722120000_stage11_notifications_settings.sql` adds:

- `notification_preferences`;
- `data_export_requests`;
- `account_deletion_requests`;
- participant-owned RLS policies;
- privacy-safe notification serialization and pagination;
- RPC-only read-state and preference mutations;
- idempotent export requests;
- typed `DELETE` confirmation and a 14-day deletion recovery period;
- blocked-user display and unblock RPCs;
- audit events for privacy-sensitive changes.

The Flutter client never receives push/email delivery metadata, export storage
paths, or another user's preference records. Direct authenticated notification
updates are revoked; the client uses recipient-checked RPCs while retaining
RLS-filtered select access for Realtime updates.

## Demo walkthrough

1. Complete customer or repair-professional onboarding.
2. Open the bell in the primary header and inspect unread notifications.
3. Open a linked job, request, conversation, or review.
4. Open **Profile**, then **Settings and accessibility**.
5. Change theme, effects, reduced transparency, and reduced motion.
6. Change notification preferences and request a data export.
7. Review blocked users, support information, privacy, and terms.
8. Account deletion can be exercised in demo mode, but signs the user out.

## Validation

Stage 11 adds model, repository, widget, and database contract tests, including
`supabase/tests/database/007_notifications_settings.test.sql`.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

After Docker Desktop is installed and running:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

## Stage 12 boundary

The original FixBrief plan has 12 stages. Stage 12 is the final testing and
deployment stage. It owns production push-provider registration, export-file
generation workers, final account erasure processing, full integration tests,
Android/iOS signing, environment separation, security/deployment verification,
privacy and store-publication checklists, observability, and release builds.

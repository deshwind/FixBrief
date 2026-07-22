# Stage 10 - jobs and reviews

Stage 10 turns an accepted quote into a trackable repair job for both parties.
Customers can follow progress, confirm completion, and review the repair
professional. Repair professionals can update operational statuses, review the
customer after completion, and respond once to customer feedback.

## Delivered Flutter flow

- shared role-aware job list with active and historical sections;
- customer `My repairs` navigation and repairer `Jobs` navigation;
- participant, item, agreed estimate, location area, and current status summary;
- accessible repair timeline covering request, quote, inspection, repair,
  parts, collection, and completion milestones;
- chronological status audit history with actor notes;
- role-constrained status actions and confirmation dialogs;
- customer-controlled completion confirmation;
- one reciprocal review per participant after completion;
- customer ratings for quality, communication, punctuality, value, and quote
  accuracy;
- repairer ratings for communication, description accuracy, attendance, and
  location accessibility;
- one public repairer response to each customer review;
- deterministic demo jobs and reviews for emulator testing.

Feature code is under `lib/features/jobs/`. The routes are:

- `/customer/jobs` and `/customer/jobs/:jobId`;
- `/customer/jobs/:jobId/review`;
- `/repairer/jobs` and `/repairer/jobs/:jobId`;
- `/repairer/jobs/:jobId/review`.

## Database and security boundary

Migration `20260722110000_stage10_jobs_reviews.sql` adds authenticated,
participant-scoped RPCs:

- `get_jobs()`;
- `get_job_details(uuid)`;
- `submit_job_review(uuid, jsonb)`;
- `respond_to_job_review(uuid, text)`.

The existing `set_job_status` RPC remains the single status mutation boundary.
Its trigger validates the transition, sets completion/cancellation/dispute
timestamps, and appends immutable `job_status_history` records.

The Stage 10 migration removes direct authenticated inserts into `reviews`.
The review RPC derives the direction and reviewed user from the completed job,
validates role-specific categories, and prevents a second review through the
existing `(job_id, author_id)` unique constraint. Detail responses contain only
job-safe display data; private phone, email, and address fields are excluded.

## Demo walkthrough

Run the demo command from the repository README, then:

1. On a customer account, select **Requests** and open the Ford Focus job.
2. Inspect the repair timeline and status history.
3. Confirm completion and submit all review ratings.
4. Open the completed phone repair to see reciprocal review history.
5. On a repairer account, select **Jobs**, update the active job status, open
   the completed job, review the customer, and respond to the customer review.

Demo state is held in memory and resets when the app process restarts.

## Validation

Stage 10 includes domain/repository and widget tests plus
`supabase/tests/database/006_jobs_reviews.test.sql`. The database test verifies
the RPC contract, privileges, participant isolation, privacy-safe job details,
reciprocal review creation, and repairer responses.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

After Docker Desktop is installed and running, execute the remaining database
gates before deploying:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

## Stage 11 handoff

Stage 11 now provides notifications, deep links, Profile and Settings,
appearance/accessibility and notification preferences, blocked-user controls,
data export requests, and recoverable account deletion. See
`docs/stage-11-notifications-settings.md`. Stage 12 is the final testing and
deployment stage. Stage 10 does not add payment capture or escrow.

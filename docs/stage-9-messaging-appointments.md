# Stage 9 — messaging and appointments

Stage 9 adds participant-only conversations after contact has been authorised by
a submitted quote. It supports realtime messages, private attachments, read
state, ephemeral typing indicators, appointment negotiation, blocking, and
reporting in both demo and Supabase modes.

## Delivered Flutter flow

- shared customer and repair-professional conversation inbox;
- realtime message timeline with text, images, documents, and repair evidence;
- server-confirmed sent state and conversation read state;
- short-lived typing indicators over an authorised private Broadcast channel;
- private attachment upload with a 25 MB limit and five-minute signed previews;
- appointment proposals for inspection, repair, or collection;
- inspection proposals before quote acceptance and all appointment types after
  an accepted quote has created a job;
- confirm, decline, and cancel flows;
- customer-controlled release of the exact appointment address;
- blocking/unblocking and structured user reports;
- accessible loading, empty, error, blocked, and appointment states;
- deterministic demo data for emulator use.

Relevant feature code is under `lib/features/messaging/`. Routes are `/messages`
and `/messages/:conversationId`.

## Database and security boundary

Migration `20260722100000_stage9_messaging_appointments.sql` adds the guarded
Stage 9 API. Clients retain RLS-filtered `select` access for Postgres Changes,
but message and appointment mutations are RPC-only.

The migration provides:

- privacy-safe conversation summaries and message pagination;
- idempotent message sends using a client message UUID;
- conversation-scoped appointment proposal and response RPCs;
- pre-acceptance inspection support without creating a job early;
- participant checks on every read and mutation;
- attachment paths shaped as
  `<sender-id>/<conversation-id>/<client-id>-<safe-name>`;
- exact-address release only by the customer during confirmation;
- bidirectional block enforcement in the database message trigger;
- conversation-scoped reports;
- notifications for appointment proposals and responses;
- private Realtime Broadcast policies for typing events.

Random users cannot create conversations. The existing quote-status trigger
authorises a conversation only after a repair professional submits a quote.
Attachments remain in the private `message-attachments` bucket and are served
through short-lived signed URLs.

## Supabase deployment

After Docker Desktop is installed and running:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

Before production use, open the hosted Supabase dashboard and set Realtime
Channel Restrictions to private-only. The Flutter client already creates the
typing channel with `private: true`, and the migration authorises only active
conversation participants.

Deploy the migrations only after reset, pgTAP, and lint pass. Existing Stage 4
storage policies already authorise message attachments against the same
conversation membership check.

## Demo walkthrough

Run the app with the demo configuration from the repository README.

1. Complete onboarding as either role.
2. Select **Messages** from the customer or repairer navigation.
3. Open the seeded Ford Focus conversation.
4. Send text and attach an image or document.
5. Suggest an appointment and cancel the proposal.
6. Open the overflow menu to exercise report and block/unblock states.

Demo attachments are represented by safe local metadata; no file is uploaded
outside the device.

## Validation

Stage 9 adds repository/model tests, inbox and conversation widget tests, and
`supabase/tests/database/005_messaging.test.sql`. The database test checks RPC
availability, privileges, privacy-safe reads, text sending, pre-acceptance
inspection proposals, confirmation, blocking, and private Broadcast policies.

Local Flutter validation:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Docker is not installed on this workstation, so the migration reset, pgTAP
suite, RLS runtime verification, and database lint remain deployment gates.

## Stage 10 handoff

Stage 10 now consumes the accepted `job_id`, provides job lists and timelines,
supports role-constrained status transitions and completion, and adds two-way
reviews with repairer responses. See `docs/stage-10-jobs-reviews.md`.

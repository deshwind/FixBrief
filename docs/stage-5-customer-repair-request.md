# Stage 5: Customer repair-request flow

Stage 5 implements the complete customer intake journey. It starts from the
customer home screen and ends with a durable request in `submitted` status,
ready for the Stage 6 assessment flow. It does not run AI, generate a diagnosis,
or publish a request to the repairer marketplace.

## Delivered journey

The responsive six-screen wizard covers:

1. Category search, recently used categories, suggestions, and a custom
   `Other` category.
2. Item, category-specific subcategory, brand, model, age, serial number,
   purchase/warranty details, repair history, item location, and the complete
   vehicle detail extension.
3. Written symptoms, voice-to-text, private audio notes, suggested symptom
   chips, typed structured symptoms, timing, occurrence, worsening state,
   usability, and the event immediately preceding the fault.
4. Up to 8 images, 2 videos, and 3 audio files, plus error-code evidence,
   receipts, and warranty documents. The client validates type/size, resizes
   selected images, displays previews/status, supports deletion/reordering, and
   retains stable IDs for retry.
5. A review brief with direct edit links for category, item, problem, and
   evidence sections.
6. Preferred date/time, urgency, approximate public area, private exact
   address/access notes, repairer travel distance, collection/mobile/inspection
   options, maximum callout fee, and optional budget range.

The confirmation screen explicitly says the request is awaiting assessment and
is not visible in the marketplace.

## Routes

All repair-request routes are customer-protected by the existing role guard:

```text
/customer/requests/new/category
/customer/requests/new/item
/customer/requests/new/problem
/customer/requests/new/evidence
/customer/requests/new/review
/customer/requests/new/submit
/customer/requests/new/confirmation
```

Back navigation stops active speech/audio input, saves it, and returns to the
previous step without discarding the draft. Closing the wizard saves and
returns home.

## Offline and retry behaviour

- Drift stores one active JSON draft per customer in the app's private local
  database. The controller autosaves 500 ms after changes and flushes before
  navigation.
- Text entry and wizard navigation work offline. A clear offline banner states
  that uploads and submission require internet.
- Request, symptom, and evidence UUIDs are created once on-device. Retrying uses
  the same `repair_requests.id`, `client_request_id`, symptom IDs, media IDs, and
  object paths, preventing duplicate requests or files.
- Evidence transitions through local, pending, uploading, ready, and failed
  client states. A failed item can be queued for retry without changing its ID.
- Demo mode uses the same local draft database and simulates a successful
  submission without a backend.

Connectivity status is a user-facing hint, not proof that the internet is
reachable. Production submission still handles the actual network/storage
result and leaves the local draft safe on any failure.

## Production submission order

The Supabase repository uses the Stage 4 schema and RLS contract in this order:

1. Upsert the owned request as `draft` with its stable client request ID.
2. Replace owned draft symptoms and upsert the private exact location.
3. Insert/upsert private media metadata, upload to the owner/request/media path,
   and mark each object `ready`.
4. Change the request to `submitted` only after every evidence upload succeeds.

Broad mobile categories are mapped to the granular seeded database catalogue
(for example Appliances + Washing machine maps to `washing-machines`). Exact
addresses stay in `repair_request_private_locations`; the marketplace-facing
row receives only `approximate_area`.

Raw recorded audio is kept in the app's private evidence directory only until
successful production upload. User deletion also removes the local file.

## Stage 5 database addition

`20260717100000_stage5_repair_request_documents.sql` adds the private
`repair-request-documents` bucket for PDF/text receipts and warranty evidence,
adds the bounded `repair_requests.custom_category` field, extends the existing
media bucket constraint, and extends the same owner/request storage policies
used by image, video, and audio evidence. The bucket is not public and accepts
only PDF/text files up to 15 MiB. Image receipts and warranty photos remain in
the private image bucket.

## Native permissions

- Android: internet and record-audio permissions plus the Android 30+
  speech-recognition service query.
- iOS: photo library, microphone, and speech-recognition usage descriptions.

The pickers use platform storage selectors. No broad Android storage permission
is requested.

## Validation and limits

Submission requires a category, an item name, a useful problem description (or
structured symptom/audio), an approximate area, and a private exact address.
Vehicle requests also require a registration value or `Unknown`. Budget minimum
cannot exceed budget maximum.

Client upload limits match the private buckets:

| Evidence | Count | Maximum size |
|---|---:|---:|
| Images | 8 | 12 MiB each |
| Videos | 2 | 100 MiB each |
| Audio | 3 | 25 MiB each |
| PDF/text documents | Included in file list | 15 MiB each |

Trusted backend signature inspection, malware scanning, media transcoding, and
abandoned-upload cleanup remain required before production launch, as already
recorded in the Stage 4 security handoff.

## Verification

Completed on this workstation:

- `dart format lib test`: clean
- `flutter analyze`: no issues
- `flutter test`: 13 passed, including draft JSON round-trip, in-memory Drift
  restore, validation, and the complete Stage 5 customer widget journey
- Android debug APK built successfully, installed on `emulator-5554` (Android
  15/API 35), and completed the full customer request journey with no Flutter or
  Android fatal errors

The local Supabase runtime checks remain blocked until Docker Desktop is
installed and running. After that, run:

```powershell
npx --yes supabase@latest start
npx --yes supabase@latest db reset --local
npx --yes supabase@latest test db
npx --yes supabase@latest db lint --local --level warning
```

Do not push the additive migration to a hosted project until these checks pass.

## Stage 6 boundary

Stage 6 owns AI assessment generation, safety/uncertainty labels, targeted
follow-up questions, customer assessment review, and the later transition from
`assessment_complete` to `published`. Stage 5 intentionally stops at
`submitted`.

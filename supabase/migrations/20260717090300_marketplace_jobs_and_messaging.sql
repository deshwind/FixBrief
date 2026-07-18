-- FixBrief Stage 4: quotes, jobs, appointments, messaging, reviews,
-- notifications, trust/safety, and supporting operational tables.

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.repair_requests (id) on delete restrict,
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete restrict,
  status public.quote_status not null default 'draft',
  inspection_fee_minor integer not null default 0,
  callout_fee_minor integer not null default 0,
  labour_minimum_minor integer not null default 0,
  labour_maximum_minor integer not null default 0,
  parts_minimum_minor integer not null default 0,
  parts_maximum_minor integer not null default 0,
  other_charges_minimum_minor integer not null default 0,
  other_charges_maximum_minor integer not null default 0,
  total_minimum_minor integer not null default 0,
  total_maximum_minor integer not null default 0,
  currency_code text not null default 'GBP',
  earliest_availability timestamptz,
  estimated_duration_minutes integer,
  collection_available boolean not null default false,
  mobile_repair_available boolean not null default false,
  warranty_days integer not null default 0,
  expires_at timestamptz,
  additional_comments text,
  assumptions text[] not null default '{}',
  exclusions text[] not null default '{}',
  submitted_at timestamptz,
  accepted_at timestamptz,
  rejected_at timestamptz,
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint quotes_component_nonnegative check (
    inspection_fee_minor >= 0
    and callout_fee_minor >= 0
    and labour_minimum_minor >= 0
    and labour_maximum_minor >= 0
    and parts_minimum_minor >= 0
    and parts_maximum_minor >= 0
    and other_charges_minimum_minor >= 0
    and other_charges_maximum_minor >= 0
    and total_minimum_minor >= 0
    and total_maximum_minor >= 0
  ),
  constraint quotes_component_ranges check (
    labour_minimum_minor <= labour_maximum_minor
    and parts_minimum_minor <= parts_maximum_minor
    and other_charges_minimum_minor <= other_charges_maximum_minor
    and total_minimum_minor <= total_maximum_minor
  ),
  constraint quotes_currency check (currency_code ~ '^[A-Z]{3}$'),
  constraint quotes_duration check (
    estimated_duration_minutes is null or estimated_duration_minutes between 1 and 525600
  ),
  constraint quotes_warranty check (warranty_days between 0 and 3650),
  constraint quotes_comments_length check (
    additional_comments is null or char_length(additional_comments) <= 5000
  ),
  constraint quotes_submission_state check (
    (status in ('submitted', 'accepted', 'rejected', 'expired') and submitted_at is not null)
    or status in ('draft', 'withdrawn')
  )
);

create unique index quotes_one_active_per_repairer_request
  on public.quotes (request_id, repairer_id)
  where deleted_at is null and status in ('draft', 'submitted', 'accepted');

create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  item_type public.quote_item_type not null,
  description text not null,
  minimum_minor integer not null,
  maximum_minor integer not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint quote_items_description_length check (char_length(description) between 1 and 500),
  constraint quote_items_amount_range check (
    minimum_minor >= 0 and maximum_minor >= 0 and minimum_minor <= maximum_minor
  ),
  constraint quote_items_sort_nonnegative check (sort_order >= 0)
);

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.repair_requests (id) on delete restrict,
  accepted_quote_id uuid not null unique references public.quotes (id) on delete restrict,
  customer_id uuid not null references public.customer_profiles (user_id) on delete restrict,
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete restrict,
  status public.job_status not null,
  agreed_minimum_minor integer not null,
  agreed_maximum_minor integer not null,
  currency_code text not null default 'GBP',
  accepted_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  disputed_at timestamptz,
  dispute_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint jobs_amount_range check (
    agreed_minimum_minor >= 0
    and agreed_maximum_minor >= 0
    and agreed_minimum_minor <= agreed_maximum_minor
  ),
  constraint jobs_currency check (currency_code ~ '^[A-Z]{3}$'),
  constraint jobs_party_difference check (customer_id <> repairer_id),
  constraint jobs_completion_consistency check (
    (status = 'completed' and completed_at is not null) or status <> 'completed'
  ),
  constraint jobs_cancellation_consistency check (
    (status = 'cancelled' and cancelled_at is not null) or status <> 'cancelled'
  ),
  constraint jobs_dispute_consistency check (
    (status = 'disputed' and disputed_at is not null) or status <> 'disputed'
  )
);

create table public.job_status_history (
  id bigint generated always as identity primary key,
  job_id uuid not null references public.jobs (id) on delete restrict,
  from_status public.job_status,
  to_status public.job_status not null,
  changed_by uuid references public.profiles (id) on delete set null,
  reason text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint job_status_history_reason_length check (reason is null or char_length(reason) <= 2000),
  constraint job_status_history_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  request_id uuid not null references public.repair_requests (id) on delete restrict,
  proposed_by uuid not null references public.profiles (id) on delete restrict,
  kind public.appointment_kind not null,
  status public.appointment_status not null default 'proposed',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  timezone text not null,
  location_address text,
  location_released boolean not null default false,
  response_message text,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint appointments_time_range check (ends_at > starts_at),
  constraint appointments_duration check (ends_at <= starts_at + interval '14 days'),
  constraint appointments_response_length check (
    response_message is null or char_length(response_message) <= 2000
  )
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.repair_requests (id) on delete restrict,
  job_id uuid references public.jobs (id) on delete set null,
  customer_id uuid not null references public.customer_profiles (user_id) on delete restrict,
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete restrict,
  status public.conversation_status not null default 'active',
  contact_authorised_at timestamptz not null default now(),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  deleted_at timestamptz,
  constraint conversations_party_difference check (customer_id <> repairer_id),
  constraint conversations_closed_consistency check (
    (status = 'closed' and closed_at is not null) or status = 'active'
  ),
  unique (request_id, repairer_id)
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  participant_id uuid not null references public.profiles (id) on delete restrict,
  participant_role public.app_user_role not null,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_at timestamptz,
  is_muted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, participant_id),
  constraint conversation_participants_times check (
    left_at is null or left_at >= joined_at
  )
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete restrict,
  client_message_id uuid not null,
  message_type public.message_type not null default 'text',
  body text,
  attachment_bucket text,
  attachment_path text,
  attachment_name text,
  attachment_mime_type text,
  attachment_size bigint,
  related_quote_id uuid references public.quotes (id) on delete set null,
  related_job_id uuid references public.jobs (id) on delete set null,
  related_appointment_id uuid references public.appointments (id) on delete set null,
  sent_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint messages_body_length check (body is null or char_length(body) <= 10000),
  constraint messages_content_present check (
    body is not null or attachment_path is not null or message_type in ('appointment', 'quote', 'job_system')
  ),
  constraint messages_attachment_shape check (
    (attachment_path is null and attachment_bucket is null and attachment_size is null)
    or (
      attachment_path is not null
      and attachment_bucket = 'message-attachments'
      and attachment_size between 1 and 26214400
    )
  ),
  unique (sender_id, client_message_id)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete restrict,
  author_id uuid not null references public.profiles (id) on delete restrict,
  reviewed_user_id uuid not null references public.profiles (id) on delete restrict,
  direction public.review_direction not null,
  overall_rating smallint not null,
  quality_rating smallint,
  communication_rating smallint,
  punctuality_rating smallint,
  value_rating smallint,
  quote_accuracy_rating smallint,
  description_accuracy_rating smallint,
  attendance_rating smallint,
  location_accessibility_rating smallint,
  comment text,
  repairer_response text,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reviews_distinct_users check (author_id <> reviewed_user_id),
  constraint reviews_overall_range check (overall_rating between 1 and 5),
  constraint reviews_category_ranges check (
    (quality_rating is null or quality_rating between 1 and 5)
    and (communication_rating is null or communication_rating between 1 and 5)
    and (punctuality_rating is null or punctuality_rating between 1 and 5)
    and (value_rating is null or value_rating between 1 and 5)
    and (quote_accuracy_rating is null or quote_accuracy_rating between 1 and 5)
    and (description_accuracy_rating is null or description_accuracy_rating between 1 and 5)
    and (attendance_rating is null or attendance_rating between 1 and 5)
    and (location_accessibility_rating is null or location_accessibility_rating between 1 and 5)
  ),
  constraint reviews_comment_length check (comment is null or char_length(comment) <= 5000),
  constraint reviews_response_length check (repairer_response is null or char_length(repairer_response) <= 3000),
  unique (job_id, author_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  notification_type public.notification_type not null,
  title text not null,
  body text not null,
  related_entity_type text,
  related_entity_id uuid,
  payload jsonb not null default '{}',
  deep_link text,
  dedupe_key text,
  read_at timestamptz,
  push_sent_at timestamptz,
  email_sent_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  deleted_at timestamptz,
  constraint notifications_title_length check (char_length(title) between 1 and 200),
  constraint notifications_body_length check (char_length(body) between 1 and 2000),
  constraint notifications_payload_object check (jsonb_typeof(payload) = 'object'),
  constraint notifications_deep_link_internal check (
    deep_link is null or (deep_link ~ '^/[A-Za-z0-9/_?=&.-]+$' and char_length(deep_link) <= 500)
  )
);

create unique index notifications_dedupe_key
  on public.notifications (recipient_id, dedupe_key)
  where dedupe_key is not null and deleted_at is null;

create table public.saved_repairers (
  customer_id uuid not null references public.customer_profiles (user_id) on delete cascade,
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, repairer_id),
  constraint saved_repairers_distinct_users check (customer_id <> repairer_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete restrict,
  subject_user_id uuid references public.profiles (id) on delete restrict,
  related_entity_type text,
  related_entity_id uuid,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'submitted',
  resolution_notes text,
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_not_self check (subject_user_id is null or reporter_id <> subject_user_id),
  constraint reports_details_length check (details is null or char_length(details) <= 5000),
  constraint reports_resolution_length check (resolution_notes is null or char_length(resolution_notes) <= 5000)
);

create table public.blocked_users (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_not_self check (blocker_id <> blocked_id),
  constraint blocked_users_reason_length check (reason is null or char_length(reason) <= 1000)
);

create table public.ai_usage_events (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  request_id uuid references public.repair_requests (id) on delete set null,
  operation text not null,
  status text not null,
  input_bytes integer not null default 0,
  latency_milliseconds integer,
  rate_limit_bucket timestamptz not null default date_trunc('minute', now()),
  created_at timestamptz not null default now(),
  constraint ai_usage_events_operation_length check (char_length(operation) between 2 and 80),
  constraint ai_usage_events_status_length check (char_length(status) between 2 and 40),
  constraint ai_usage_events_metrics check (
    input_bytes >= 0 and (latency_milliseconds is null or latency_milliseconds >= 0)
  )
);

create index quotes_request_status_idx on public.quotes (request_id, status, submitted_at desc)
  where deleted_at is null;
create index quotes_repairer_status_idx on public.quotes (repairer_id, status, updated_at desc)
  where deleted_at is null;
create index quote_items_quote_idx on public.quote_items (quote_id, sort_order) where deleted_at is null;
create index jobs_customer_status_idx on public.jobs (customer_id, status, updated_at desc) where deleted_at is null;
create index jobs_repairer_status_idx on public.jobs (repairer_id, status, updated_at desc) where deleted_at is null;
create index job_status_history_job_idx on public.job_status_history (job_id, created_at, id);
create index appointments_job_idx on public.appointments (job_id, starts_at) where deleted_at is null;
create index appointments_request_idx on public.appointments (request_id, starts_at) where deleted_at is null;
create index conversations_customer_idx on public.conversations (customer_id, last_message_at desc) where deleted_at is null;
create index conversations_repairer_idx on public.conversations (repairer_id, last_message_at desc) where deleted_at is null;
create index conversation_participants_user_idx on public.conversation_participants (participant_id, conversation_id)
  where left_at is null;
create index messages_conversation_page_idx on public.messages (conversation_id, created_at desc, id)
  where deleted_at is null;
create index reviews_reviewed_user_idx on public.reviews (reviewed_user_id, created_at desc) where deleted_at is null;
create index notifications_unread_idx on public.notifications (recipient_id, read_at, created_at desc)
  where deleted_at is null;
create index reports_reporter_idx on public.reports (reporter_id, created_at desc);
create index reports_status_idx on public.reports (status, created_at);
create index blocked_users_blocked_idx on public.blocked_users (blocked_id, blocker_id);
create index ai_usage_events_rate_idx on public.ai_usage_events (user_id, operation, rate_limit_bucket);

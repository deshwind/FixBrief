-- FixBrief Stage 4: customer repair requests, evidence, private locations,
-- and immutable/versioned AI assessment data.

create table public.repair_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customer_profiles (user_id) on delete restrict,
  category_id uuid references public.repair_categories (id) on delete restrict,
  subcategory_id uuid references public.repair_subcategories (id) on delete restrict,
  client_request_id uuid not null default gen_random_uuid(),
  item_name text,
  brand text,
  model text,
  approximate_age_years numeric(5, 1),
  serial_number text,
  purchase_date date,
  warranty_status text,
  previous_repairs text,
  item_location_label text,
  vehicle_registration text,
  vehicle_make text,
  vehicle_model text,
  vehicle_year integer,
  vehicle_mileage integer,
  vehicle_fuel_type text,
  vehicle_transmission text,
  problem_description text,
  structured_brief text,
  preferred_repair_date date,
  preferred_time_start time,
  preferred_time_end time,
  urgency public.urgency_level not null default 'flexible',
  approximate_area text,
  approximate_location extensions.geography(point, 4326),
  travel_distance_kilometres numeric(6, 2),
  collection_required boolean not null default false,
  mobile_repair_required boolean not null default false,
  inspection_required boolean not null default false,
  maximum_callout_fee_minor integer,
  budget_minimum_minor integer,
  budget_maximum_minor integer,
  currency_code text not null default 'GBP',
  evidence_visible_to_eligible_repairers boolean not null default true,
  status public.request_status not null default 'draft',
  version integer not null default 1,
  published_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_requests_item_name_length check (
    item_name is null or char_length(item_name) between 2 and 160
  ),
  constraint repair_requests_description_length check (
    problem_description is null or char_length(problem_description) <= 10000
  ),
  constraint repair_requests_brief_length check (
    structured_brief is null or char_length(structured_brief) <= 15000
  ),
  constraint repair_requests_age_nonnegative check (
    approximate_age_years is null or approximate_age_years >= 0
  ),
  constraint repair_requests_vehicle_year check (
    vehicle_year is null or vehicle_year between 1886 and 2200
  ),
  constraint repair_requests_vehicle_mileage check (
    vehicle_mileage is null or vehicle_mileage >= 0
  ),
  constraint repair_requests_time_range check (
    preferred_time_end is null or preferred_time_start is null or preferred_time_end > preferred_time_start
  ),
  constraint repair_requests_travel_range check (
    travel_distance_kilometres is null or travel_distance_kilometres between 0 and 500
  ),
  constraint repair_requests_fee_nonnegative check (
    maximum_callout_fee_minor is null or maximum_callout_fee_minor >= 0
  ),
  constraint repair_requests_budget_range check (
    (budget_minimum_minor is null or budget_minimum_minor >= 0)
    and (budget_maximum_minor is null or budget_maximum_minor >= 0)
    and (
      budget_minimum_minor is null
      or budget_maximum_minor is null
      or budget_minimum_minor <= budget_maximum_minor
    )
  ),
  constraint repair_requests_currency check (currency_code ~ '^[A-Z]{3}$'),
  constraint repair_requests_version_positive check (version > 0),
  constraint repair_requests_publish_consistency check (
    (status in ('published', 'under_review', 'quotes_received', 'quote_accepted', 'archived') and published_at is not null)
    or status not in ('published', 'under_review', 'quotes_received', 'quote_accepted', 'archived')
  ),
  unique (customer_id, client_request_id)
);

create table public.repair_request_private_locations (
  request_id uuid primary key references public.repair_requests (id) on delete cascade,
  customer_id uuid not null references public.customer_profiles (user_id) on delete restrict,
  exact_address text not null,
  exact_location extensions.geography(point, 4326),
  access_instructions text,
  authorised_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_request_private_locations_address_length check (
    char_length(exact_address) between 5 and 500
  ),
  constraint repair_request_private_locations_instructions_length check (
    access_instructions is null or char_length(access_instructions) <= 1000
  )
);

create table public.repair_request_symptoms (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.repair_requests (id) on delete cascade,
  kind public.symptom_kind not null,
  description text not null,
  source public.symptom_source not null default 'typed',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_request_symptoms_description_length check (
    char_length(description) between 1 and 2000
  ),
  constraint repair_request_symptoms_sort_nonnegative check (sort_order >= 0)
);

create table public.repair_request_media (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.repair_requests (id) on delete cascade,
  uploaded_by uuid not null references public.profiles (id) on delete restrict,
  kind public.media_kind not null,
  bucket_name text not null,
  object_path text not null,
  original_filename text,
  mime_type text not null,
  byte_size bigint not null,
  checksum_sha256 text,
  duration_milliseconds integer,
  width_pixels integer,
  height_pixels integer,
  sort_order integer not null default 0,
  upload_status public.upload_status not null default 'pending',
  failure_reason text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_request_media_bucket check (
    bucket_name in ('repair-request-images', 'repair-request-videos', 'repair-request-audio')
  ),
  constraint repair_request_media_path_length check (char_length(object_path) between 5 and 1024),
  constraint repair_request_media_mime_length check (char_length(mime_type) between 3 and 120),
  constraint repair_request_media_byte_size check (byte_size > 0 and byte_size <= 104857600),
  constraint repair_request_media_checksum check (
    checksum_sha256 is null or checksum_sha256 ~ '^[a-f0-9]{64}$'
  ),
  constraint repair_request_media_dimensions check (
    (width_pixels is null or width_pixels > 0)
    and (height_pixels is null or height_pixels > 0)
    and (duration_milliseconds is null or duration_milliseconds >= 0)
  ),
  constraint repair_request_media_sort_nonnegative check (sort_order >= 0),
  unique (bucket_name, object_path)
);

create table public.ai_assessments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.repair_requests (id) on delete cascade,
  version integer not null,
  problem_summary text not null,
  fault_categories text[] not null default '{}',
  confidence public.confidence_level not null,
  urgency public.urgency_level not null,
  safety_risk public.risk_level not null,
  recommended_professional_type text,
  missing_information text[] not null default '{}',
  stop_using_item boolean not null default false,
  safety_warning text,
  structured_repair_brief jsonb not null,
  suggested_evidence text[] not null default '{}',
  suggested_inspection_type text,
  input_hash text not null,
  model_identifier text not null,
  prompt_version text not null,
  safety_version text not null,
  validation_status public.assessment_validation_status not null default 'pending',
  validation_errors jsonb not null default '[]',
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint ai_assessments_version_positive check (version > 0),
  constraint ai_assessments_summary_length check (char_length(problem_summary) between 1 and 5000),
  constraint ai_assessments_brief_object check (jsonb_typeof(structured_repair_brief) = 'object'),
  constraint ai_assessments_validation_errors_array check (jsonb_typeof(validation_errors) = 'array'),
  constraint ai_assessments_input_hash check (input_hash ~ '^[a-f0-9]{64}$'),
  unique (request_id, version)
);

create table public.ai_possible_causes (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.ai_assessments (id) on delete cascade,
  cause text not null,
  confidence numeric(4, 3) not null,
  reasoning_summary text,
  hidden_from_customer boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint ai_possible_causes_cause_length check (char_length(cause) between 1 and 1000),
  constraint ai_possible_causes_confidence check (confidence between 0 and 1),
  constraint ai_possible_causes_reason_length check (
    reasoning_summary is null or char_length(reasoning_summary) <= 3000
  ),
  constraint ai_possible_causes_sort_nonnegative check (sort_order >= 0)
);

create table public.ai_follow_up_questions (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.ai_assessments (id) on delete cascade,
  question text not null,
  answer text,
  answer_source public.symptom_source,
  is_essential boolean not null default false,
  is_skipped boolean not null default false,
  sort_order integer not null default 0,
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_follow_up_questions_question_length check (char_length(question) between 1 and 1000),
  constraint ai_follow_up_questions_answer_length check (answer is null or char_length(answer) <= 4000),
  constraint ai_follow_up_questions_answer_state check (
    not (is_skipped and answer is not null)
  ),
  constraint ai_follow_up_questions_sort_nonnegative check (sort_order >= 0)
);

create index repair_requests_customer_status_idx on public.repair_requests (customer_id, status, updated_at desc)
  where deleted_at is null;
create index repair_requests_marketplace_idx on public.repair_requests (status, urgency, published_at desc)
  where deleted_at is null and status in ('published', 'under_review', 'quotes_received');
create index repair_requests_category_idx on public.repair_requests (category_id, subcategory_id, status)
  where deleted_at is null;
create index repair_requests_location_gist on public.repair_requests using gist (approximate_location);
create index repair_requests_problem_search_idx on public.repair_requests
  using gin (problem_description extensions.gin_trgm_ops)
  where deleted_at is null and status in ('published', 'under_review', 'quotes_received');
create index repair_request_private_locations_customer_idx on public.repair_request_private_locations (customer_id)
  where deleted_at is null;
create index repair_request_private_locations_location_gist
  on public.repair_request_private_locations using gist (exact_location);
create index repair_request_symptoms_request_idx on public.repair_request_symptoms (request_id, sort_order)
  where deleted_at is null;
create index repair_request_media_request_idx on public.repair_request_media (request_id, sort_order)
  where deleted_at is null and upload_status = 'ready';
create index repair_request_media_uploaded_by_idx on public.repair_request_media (uploaded_by);
create index ai_assessments_request_idx on public.ai_assessments (request_id, version desc);
create index ai_possible_causes_assessment_idx on public.ai_possible_causes (assessment_id, sort_order);
create index ai_follow_up_questions_assessment_idx on public.ai_follow_up_questions (assessment_id, sort_order);

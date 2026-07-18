-- FixBrief Stage 4: identities, role-specific profiles, repair catalogue,
-- service coverage, availability, idempotency, and audit records.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.app_user_role,
  display_name text,
  avatar_path text,
  onboarding_status public.onboarding_status not null default 'not_started',
  account_status public.account_status not null default 'active',
  terms_accepted_at timestamptz,
  privacy_acknowledged_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  deleted_at timestamptz,
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) between 2 and 120
  ),
  constraint profiles_role_onboarding_consistency check (
    role is not null or onboarding_status = 'not_started'
  ),
  constraint profiles_deleted_consistency check (
    (account_status = 'deleted') = (deleted_at is not null)
  )
);

create table public.customer_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  full_name text,
  phone_number text,
  location_label text,
  approximate_location extensions.geography(point, 4326),
  preferred_contact public.preferred_contact_method not null default 'in_app',
  push_notifications boolean not null default true,
  email_notifications boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_profiles_full_name_length check (
    full_name is null or char_length(full_name) between 2 and 120
  ),
  constraint customer_profiles_phone_length check (
    phone_number is null or char_length(phone_number) between 7 and 32
  ),
  constraint customer_profiles_location_length check (
    location_label is null or char_length(location_label) between 2 and 200
  )
);

create table public.repairer_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  full_name text,
  business_name text,
  logo_path text,
  phone_number text,
  business_email text,
  business_description text,
  years_experience integer,
  qualifications text[] not null default '{}',
  inspection_fee_minor integer not null default 0,
  currency_code text not null default 'GBP',
  service_radius_kilometres numeric(6, 2) not null default 0,
  business_address text,
  business_location extensions.geography(point, 4326),
  working_hours text,
  emergency_service_available boolean not null default false,
  mobile_repair_available boolean not null default false,
  collection_service_available boolean not null default false,
  verification_status public.verification_status not null default 'unverified',
  verified_at timestamptz,
  verified_by uuid references auth.users (id) on delete set null,
  verification_notes text,
  is_marketplace_visible boolean not null default false,
  average_rating numeric(3, 2) not null default 0,
  review_count integer not null default 0,
  completed_job_count integer not null default 0,
  response_rate numeric(5, 2) not null default 0,
  quote_acceptance_rate numeric(5, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repairer_profiles_full_name_length check (
    full_name is null or char_length(full_name) between 2 and 120
  ),
  constraint repairer_profiles_business_name_length check (
    business_name is null or char_length(business_name) between 2 and 160
  ),
  constraint repairer_profiles_description_length check (
    business_description is null or char_length(business_description) <= 2000
  ),
  constraint repairer_profiles_phone_length check (
    phone_number is null or char_length(phone_number) between 7 and 32
  ),
  constraint repairer_profiles_email_length check (
    business_email is null or char_length(business_email) <= 320
  ),
  constraint repairer_profiles_experience_range check (
    years_experience is null or years_experience between 0 and 80
  ),
  constraint repairer_profiles_fee_nonnegative check (inspection_fee_minor >= 0),
  constraint repairer_profiles_currency check (currency_code ~ '^[A-Z]{3}$'),
  constraint repairer_profiles_radius_range check (
    service_radius_kilometres between 0 and 500
  ),
  constraint repairer_profiles_rating_range check (
    average_rating between 0 and 5 and review_count >= 0
  ),
  constraint repairer_profiles_metric_ranges check (
    completed_job_count >= 0
    and response_rate between 0 and 100
    and quote_acceptance_rate between 0 and 100
  ),
  constraint repairer_profiles_verification_consistency check (
    (verification_status = 'verified' and verified_at is not null)
    or verification_status <> 'verified'
  )
);

create table public.repair_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  icon_token text not null,
  accent_token text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_categories_name_length check (char_length(name) between 2 and 100),
  constraint repair_categories_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint repair_categories_sort_nonnegative check (sort_order >= 0)
);

create unique index repair_categories_name_active_key
  on public.repair_categories (lower(name))
  where deleted_at is null;

create table public.repair_subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.repair_categories (id) on delete restrict,
  name text not null,
  slug text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repair_subcategories_name_length check (char_length(name) between 2 and 100),
  constraint repair_subcategories_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint repair_subcategories_sort_nonnegative check (sort_order >= 0),
  unique (category_id, slug)
);

create table public.repairer_specialisations (
  id uuid primary key default gen_random_uuid(),
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete cascade,
  category_id uuid not null references public.repair_categories (id) on delete restrict,
  subcategory_id uuid references public.repair_subcategories (id) on delete restrict,
  specialisation text not null default 'General',
  years_experience integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repairer_specialisations_label_length check (
    char_length(specialisation) between 2 and 120
  ),
  constraint repairer_specialisations_experience_range check (
    years_experience is null or years_experience between 0 and 80
  ),
  unique nulls not distinct (repairer_id, category_id, subcategory_id, specialisation)
);

create table public.repairer_certifications (
  id uuid primary key default gen_random_uuid(),
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete cascade,
  name text not null,
  issuer text,
  qualification_number text,
  issued_on date,
  expires_on date,
  object_path text,
  verification_status public.verification_status not null default 'unverified',
  verified_at timestamptz,
  verified_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint repairer_certifications_name_length check (char_length(name) between 2 and 160),
  constraint repairer_certifications_dates check (
    expires_on is null or issued_on is null or expires_on >= issued_on
  ),
  constraint repairer_certifications_verification_consistency check (
    (verification_status = 'verified' and verified_at is not null)
    or verification_status <> 'verified'
  )
);

create table public.service_areas (
  id uuid primary key default gen_random_uuid(),
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete cascade,
  area_name text not null,
  centre extensions.geography(point, 4326),
  radius_kilometres numeric(6, 2) not null,
  emergency_service boolean not null default false,
  mobile_repair boolean not null default false,
  collection_service boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint service_areas_name_length check (char_length(area_name) between 2 and 200),
  constraint service_areas_radius_range check (radius_kilometres > 0 and radius_kilometres <= 500)
);

create table public.availability_slots (
  id uuid primary key default gen_random_uuid(),
  repairer_id uuid not null references public.repairer_profiles (user_id) on delete cascade,
  kind public.availability_kind not null,
  weekday smallint,
  starts_at time,
  ends_at time,
  valid_from date,
  valid_until date,
  timezone text not null default 'Europe/London',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint availability_slots_weekday check (weekday is null or weekday between 1 and 7),
  constraint availability_slots_time_range check (
    starts_at is null or ends_at is null or starts_at < ends_at
  ),
  constraint availability_slots_date_range check (
    valid_until is null or valid_from is null or valid_until >= valid_from
  ),
  constraint availability_slots_shape check (
    (kind = 'recurring' and weekday is not null and starts_at is not null and ends_at is not null)
    or (kind <> 'recurring' and valid_from is not null)
  )
);

create table public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  scope text not null,
  idempotency_key text not null,
  request_hash text,
  resource_type text,
  resource_id uuid,
  result jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint idempotency_keys_scope_length check (char_length(scope) between 2 and 80),
  constraint idempotency_keys_key_length check (char_length(idempotency_key) between 8 and 200),
  unique (user_id, scope, idempotency_key)
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  outcome text not null default 'success',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint audit_events_action_length check (char_length(action) between 2 and 120),
  constraint audit_events_entity_type_length check (char_length(entity_type) between 2 and 80),
  constraint audit_events_outcome_length check (char_length(outcome) between 2 and 40),
  constraint audit_events_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index profiles_role_status_idx on public.profiles (role, account_status) where deleted_at is null;
create index customer_profiles_location_gist on public.customer_profiles using gist (approximate_location);
create index repairer_profiles_marketplace_idx on public.repairer_profiles (verification_status, average_rating desc)
  where deleted_at is null and is_marketplace_visible;
create index repairer_profiles_business_search_idx on public.repairer_profiles
  using gin (business_name extensions.gin_trgm_ops)
  where deleted_at is null;
create index repair_subcategories_category_idx on public.repair_subcategories (category_id, sort_order)
  where deleted_at is null and is_active;
create index repairer_specialisations_repairer_idx on public.repairer_specialisations (repairer_id)
  where deleted_at is null;
create index repairer_specialisations_category_idx on public.repairer_specialisations (category_id, subcategory_id, repairer_id)
  where deleted_at is null;
create index repairer_certifications_repairer_idx on public.repairer_certifications (repairer_id)
  where deleted_at is null;
create index service_areas_repairer_idx on public.service_areas (repairer_id) where deleted_at is null and is_active;
create index service_areas_centre_gist on public.service_areas using gist (centre);
create index availability_slots_repairer_idx on public.availability_slots (repairer_id, kind, weekday)
  where deleted_at is null and is_active;
create index idempotency_keys_expiry_idx on public.idempotency_keys (expires_at);
create index audit_events_entity_idx on public.audit_events (entity_type, entity_id, created_at desc);
create index audit_events_actor_idx on public.audit_events (actor_id, created_at desc);

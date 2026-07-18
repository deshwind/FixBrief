-- FixBrief Stage 4: security-definer helpers and the only client-callable
-- functions for role assignment, onboarding, contact, quote acceptance,
-- and job status changes.

create or replace function private.users_are_blocked(first_user uuid, second_user uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.blocked_users as b
    where (b.blocker_id = first_user and b.blocked_id = second_user)
       or (b.blocker_id = second_user and b.blocked_id = first_user)
  )
$$;

create or replace function private.can_view_marketplace_request(
  target_request_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, extensions
as $$
  select exists (
    select 1
    from public.repair_requests as r
    join public.repairer_profiles as rp on rp.user_id = viewer_id
    join public.profiles as p on p.id = rp.user_id
    where r.id = target_request_id
      and r.deleted_at is null
      and r.status in ('published', 'under_review', 'quotes_received')
      and p.role = 'repairer'
      and p.account_status = 'active'
      and p.deleted_at is null
      and rp.deleted_at is null
      and rp.verification_status = 'verified'
      and rp.is_marketplace_visible
      and not private.users_are_blocked(r.customer_id, viewer_id)
      and (not r.collection_required or rp.collection_service_available)
      and (not r.mobile_repair_required or rp.mobile_repair_available)
      and exists (
        select 1
        from public.repairer_specialisations as rs
        where rs.repairer_id = viewer_id
          and rs.category_id = r.category_id
          and (r.subcategory_id is null or rs.subcategory_id is null or rs.subcategory_id = r.subcategory_id)
          and rs.deleted_at is null
      )
      and (
        r.approximate_location is null
        or exists (
          select 1
          from public.service_areas as sa
          where sa.repairer_id = viewer_id
            and sa.is_active
            and sa.deleted_at is null
            and (
              sa.centre is null
              or extensions.st_dwithin(
                sa.centre,
                r.approximate_location,
                sa.radius_kilometres * 1000
              )
            )
        )
        or (
          rp.business_location is not null
          and extensions.st_dwithin(
            rp.business_location,
            r.approximate_location,
            rp.service_radius_kilometres * 1000
          )
        )
      )
  )
$$;

create or replace function private.can_access_conversation(
  target_conversation_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.conversation_participants as cp
    where cp.conversation_id = target_conversation_id
      and cp.participant_id = viewer_id
      and cp.left_at is null
  )
$$;

create or replace function private.can_access_private_location(
  target_request_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.repair_requests as r
    where r.id = target_request_id
      and r.customer_id = viewer_id
  ) or exists (
    select 1
    from public.jobs as j
    where j.request_id = target_request_id
      and j.repairer_id = viewer_id
      and j.deleted_at is null
  ) or exists (
    select 1
    from public.appointments as a
    join public.jobs as j on j.id = a.job_id
    where a.request_id = target_request_id
      and j.repairer_id = viewer_id
      and a.status in ('confirmed', 'completed')
      and a.location_released
      and a.deleted_at is null
  )
$$;

create or replace function private.can_access_request_evidence(
  target_request_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.repair_requests as r
    where r.id = target_request_id
      and r.customer_id = viewer_id
  ) or exists (
    select 1
    from public.jobs as j
    where j.request_id = target_request_id
      and j.repairer_id = viewer_id
      and j.deleted_at is null
  ) or exists (
    select 1
    from public.repair_requests as r
    where r.id = target_request_id
      and r.evidence_visible_to_eligible_repairers
      and private.can_view_marketplace_request(r.id, viewer_id)
  )
$$;

create or replace function private.ensure_conversation(
  target_request_id uuid,
  target_repairer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_customer_id uuid;
  conversation_id uuid;
begin
  select r.customer_id into target_customer_id
  from public.repair_requests as r
  where r.id = target_request_id and r.deleted_at is null;

  if target_customer_id is null then
    raise exception 'Repair request not found.' using errcode = 'P0002';
  end if;

  insert into public.conversations (
    request_id,
    customer_id,
    repairer_id
  ) values (
    target_request_id,
    target_customer_id,
    target_repairer_id
  )
  on conflict (request_id, repairer_id) do update
    set status = 'active', closed_at = null, updated_at = now()
  returning id into conversation_id;

  insert into public.conversation_participants (
    conversation_id,
    participant_id,
    participant_role
  ) values
    (conversation_id, target_customer_id, 'customer'),
    (conversation_id, target_repairer_id, 'repairer')
  on conflict (conversation_id, participant_id) do update
    set left_at = null, updated_at = now();

  return conversation_id;
end;
$$;

create or replace function private.authorise_conversation_after_quote()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform private.ensure_conversation(new.request_id, new.repairer_id);
  end if;
  return new;
end;
$$;

create trigger authorise_conversation_after_quote
  after insert or update of status on public.quotes
  for each row execute function private.authorise_conversation_after_quote();

create or replace function public.claim_role(selected_role text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  parsed_role public.app_user_role;
  existing_role public.app_user_role;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  if selected_role not in ('customer', 'repairer') then
    raise exception 'Account type must be customer or repairer.' using errcode = '22023';
  end if;
  parsed_role := selected_role::public.app_user_role;

  if not exists (
    select 1 from auth.users as u
    where u.id = caller_id and u.email_confirmed_at is not null
  ) then
    raise exception 'Verify your email before choosing an account type.' using errcode = '42501';
  end if;

  select p.role into existing_role
  from public.profiles as p
  where p.id = caller_id
  for update;

  if not found then
    raise exception 'Profile not found.' using errcode = 'P0002';
  end if;
  if existing_role is not null then
    raise exception 'The account type has already been selected.' using errcode = '23505';
  end if;

  update public.profiles
  set role = parsed_role, onboarding_status = 'in_progress', updated_at = now()
  where id = caller_id;

  if parsed_role = 'customer' then
    insert into public.customer_profiles (user_id) values (caller_id);
  else
    insert into public.repairer_profiles (user_id) values (caller_id);
  end if;

  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'account.role_claimed', 'profile', caller_id);
end;
$$;

create or replace function public.claim_user_role(selected_role public.app_user_role)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  perform public.claim_role(selected_role::text);
end;
$$;

create or replace function public.complete_customer_onboarding(profile_data jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  full_name_value text := btrim(coalesce(profile_data ->> 'full_name', ''));
  phone_value text := btrim(coalesce(profile_data ->> 'phone_number', ''));
  location_value text := btrim(coalesce(profile_data ->> 'location', ''));
  contact_value text := coalesce(profile_data ->> 'preferred_contact', 'in_app');
  avatar_value text := nullif(btrim(coalesce(profile_data ->> 'avatar_path', '')), '');
  parsed_contact public.preferred_contact_method;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if jsonb_typeof(profile_data) <> 'object' then
    raise exception 'Customer profile data must be an object.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.profiles as p
    where p.id = caller_id
      and p.role = 'customer'
      and p.onboarding_status in ('in_progress', 'rejected')
      and p.account_status = 'active'
  ) then
    raise exception 'This customer account cannot be onboarded.' using errcode = '42501';
  end if;
  if char_length(full_name_value) not between 2 and 120
    or char_length(phone_value) not between 7 and 32
    or char_length(location_value) not between 2 and 200 then
    raise exception 'Name, phone number, or location is invalid.' using errcode = '22023';
  end if;

  contact_value := case contact_value when 'inApp' then 'in_app' else contact_value end;
  if contact_value not in ('in_app', 'email', 'phone', 'sms') then
    raise exception 'Preferred contact method is invalid.' using errcode = '22023';
  end if;
  parsed_contact := contact_value::public.preferred_contact_method;

  if avatar_value is not null and split_part(avatar_value, '/', 1) <> caller_id::text then
    raise exception 'Profile image path does not belong to this account.' using errcode = '42501';
  end if;

  update public.customer_profiles
  set
    full_name = full_name_value,
    phone_number = phone_value,
    location_label = location_value,
    preferred_contact = parsed_contact,
    push_notifications = coalesce((profile_data ->> 'push_notifications')::boolean, true),
    email_notifications = coalesce((profile_data ->> 'email_notifications')::boolean, true),
    updated_at = now(),
    deleted_at = null
  where user_id = caller_id;

  update public.profiles
  set
    display_name = full_name_value,
    avatar_path = avatar_value,
    onboarding_status = 'approved',
    updated_at = now()
  where id = caller_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'onboarding.customer_completed', 'profile', caller_id);
end;
$$;

create or replace function public.submit_repairer_onboarding(profile_data jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  full_name_value text := btrim(coalesce(profile_data ->> 'full_name', ''));
  business_name_value text := btrim(coalesce(profile_data ->> 'business_name', ''));
  phone_value text := btrim(coalesce(profile_data ->> 'phone_number', ''));
  email_value text := lower(btrim(coalesce(profile_data ->> 'email', '')));
  description_value text := btrim(coalesce(profile_data ->> 'business_description', ''));
  address_value text := btrim(coalesce(profile_data ->> 'address', ''));
  working_hours_value text := btrim(coalesce(profile_data ->> 'working_hours', ''));
  logo_value text := nullif(btrim(coalesce(profile_data ->> 'business_logo_path', '')), '');
  category_name text;
  specialisation_name text;
  certification_name text;
  category_record public.repair_categories%rowtype;
  first_category_id uuid;
  selected_category_count integer := 0;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if jsonb_typeof(profile_data) <> 'object'
    or jsonb_typeof(profile_data -> 'repair_categories') <> 'array'
    or jsonb_typeof(profile_data -> 'specialisations') <> 'array'
    or jsonb_typeof(profile_data -> 'qualifications') <> 'array'
    or jsonb_typeof(profile_data -> 'certifications') <> 'array' then
    raise exception 'Repairer profile data is incomplete.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.profiles as p
    where p.id = caller_id
      and p.role = 'repairer'
      and p.onboarding_status in ('in_progress', 'rejected')
      and p.account_status = 'active'
  ) then
    raise exception 'This repairer account cannot be onboarded.' using errcode = '42501';
  end if;

  if char_length(full_name_value) not between 2 and 120
    or char_length(business_name_value) not between 2 and 160
    or char_length(phone_value) not between 7 and 32
    or char_length(email_value) not between 3 and 320
    or email_value !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
    or char_length(description_value) not between 20 and 2000
    or char_length(address_value) not between 5 and 500
    or char_length(working_hours_value) not between 2 and 1000 then
    raise exception 'Required business profile fields are invalid.' using errcode = '22023';
  end if;
  if (profile_data ->> 'years_experience')::integer not between 0 and 80
    or (profile_data ->> 'inspection_fee_minor')::integer < 0
    or (profile_data ->> 'service_radius_kilometres')::numeric not between 0.1 and 500 then
    raise exception 'Experience, fee, or service radius is invalid.' using errcode = '22023';
  end if;
  if logo_value is not null and split_part(logo_value, '/', 1) <> caller_id::text then
    raise exception 'Business logo path does not belong to this account.' using errcode = '42501';
  end if;

  update public.repairer_profiles
  set
    full_name = full_name_value,
    business_name = business_name_value,
    logo_path = logo_value,
    phone_number = phone_value,
    business_email = email_value,
    business_description = description_value,
    years_experience = (profile_data ->> 'years_experience')::integer,
    qualifications = array(
      select btrim(value)
      from jsonb_array_elements_text(profile_data -> 'qualifications')
      where char_length(btrim(value)) between 2 and 200
    ),
    inspection_fee_minor = (profile_data ->> 'inspection_fee_minor')::integer,
    service_radius_kilometres = (profile_data ->> 'service_radius_kilometres')::numeric,
    business_address = address_value,
    working_hours = working_hours_value,
    emergency_service_available = coalesce((profile_data ->> 'emergency_service_available')::boolean, false),
    mobile_repair_available = coalesce((profile_data ->> 'mobile_repair_available')::boolean, false),
    collection_service_available = coalesce((profile_data ->> 'collection_service_available')::boolean, false),
    verification_status = 'pending',
    verified_at = null,
    verified_by = null,
    is_marketplace_visible = false,
    updated_at = now(),
    deleted_at = null
  where user_id = caller_id;

  delete from public.repairer_specialisations where repairer_id = caller_id;
  for category_name in
    select distinct btrim(value)
    from jsonb_array_elements_text(profile_data -> 'repair_categories')
  loop
    select * into category_record
    from public.repair_categories as c
    where lower(c.name) = lower(category_name)
      and c.is_active
      and c.deleted_at is null;
    if not found then
      raise exception 'Unknown repair category: %.', category_name using errcode = '22023';
    end if;
    first_category_id := coalesce(first_category_id, category_record.id);
    selected_category_count := selected_category_count + 1;
    insert into public.repairer_specialisations (
      repairer_id,
      category_id,
      specialisation,
      years_experience
    ) values (
      caller_id,
      category_record.id,
      'General',
      (profile_data ->> 'years_experience')::integer
    );
  end loop;

  if selected_category_count = 0 then
    raise exception 'Choose at least one repair category.' using errcode = '22023';
  end if;

  for specialisation_name in
    select distinct btrim(value)
    from jsonb_array_elements_text(profile_data -> 'specialisations')
    where char_length(btrim(value)) between 2 and 120
  loop
    insert into public.repairer_specialisations (
      repairer_id,
      category_id,
      specialisation,
      years_experience
    ) values (
      caller_id,
      first_category_id,
      specialisation_name,
      (profile_data ->> 'years_experience')::integer
    )
    on conflict (repairer_id, category_id, subcategory_id, specialisation)
      do update set deleted_at = null, updated_at = now();
  end loop;

  delete from public.repairer_certifications where repairer_id = caller_id;
  for certification_name in
    select distinct btrim(value)
    from jsonb_array_elements_text(profile_data -> 'certifications')
    where char_length(btrim(value)) between 2 and 160
  loop
    insert into public.repairer_certifications (repairer_id, name)
    values (caller_id, certification_name);
  end loop;

  delete from public.service_areas where repairer_id = caller_id;
  insert into public.service_areas (
    repairer_id,
    area_name,
    radius_kilometres,
    emergency_service,
    mobile_repair,
    collection_service
  ) values (
    caller_id,
    address_value,
    (profile_data ->> 'service_radius_kilometres')::numeric,
    coalesce((profile_data ->> 'emergency_service_available')::boolean, false),
    coalesce((profile_data ->> 'mobile_repair_available')::boolean, false),
    coalesce((profile_data ->> 'collection_service_available')::boolean, false)
  );

  update public.profiles
  set
    display_name = full_name_value,
    avatar_path = logo_value,
    onboarding_status = 'submitted',
    updated_at = now()
  where id = caller_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'onboarding.repairer_submitted', 'profile', caller_id);
end;
$$;

create or replace function public.authorise_contact(
  target_request_id uuid,
  target_repairer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  customer_id uuid;
begin
  select r.customer_id into customer_id
  from public.repair_requests as r
  where r.id = target_request_id and r.deleted_at is null;

  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if caller_id not in (customer_id, target_repairer_id) then
    raise exception 'You are not part of this repair request.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.quotes as q
    where q.request_id = target_request_id
      and q.repairer_id = target_repairer_id
      and q.status in ('submitted', 'accepted')
      and q.deleted_at is null
  ) and not exists (
    select 1 from public.jobs as j
    where j.request_id = target_request_id
      and j.repairer_id = target_repairer_id
      and j.deleted_at is null
  ) then
    raise exception 'Contact has not been authorised for this request.' using errcode = '42501';
  end if;
  return private.ensure_conversation(target_request_id, target_repairer_id);
end;
$$;

create or replace function public.accept_quote(
  quote_id uuid,
  idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_quote public.quotes%rowtype;
  selected_request public.repair_requests%rowtype;
  existing_job_id uuid;
  new_job_id uuid;
  initial_status public.job_status;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if char_length(coalesce(idempotency_key, '')) not between 8 and 200 then
    raise exception 'A valid idempotency key is required.' using errcode = '22023';
  end if;

  select k.resource_id into existing_job_id
  from public.idempotency_keys as k
  where k.user_id = caller_id
    and k.scope = 'accept_quote'
    and k.idempotency_key = accept_quote.idempotency_key
    and k.expires_at > now();
  if existing_job_id is not null then
    return existing_job_id;
  end if;

  select * into selected_quote
  from public.quotes as q
  where q.id = quote_id
  for update;
  if not found or selected_quote.deleted_at is not null then
    raise exception 'Quote not found.' using errcode = 'P0002';
  end if;

  select * into selected_request
  from public.repair_requests as r
  where r.id = selected_quote.request_id
  for update;
  if selected_request.customer_id <> caller_id then
    raise exception 'Only the request owner can accept a quote.' using errcode = '42501';
  end if;
  if selected_quote.status <> 'submitted'
    or selected_quote.expires_at is null
    or selected_quote.expires_at <= now() then
    raise exception 'This quote is no longer available.' using errcode = '23514';
  end if;
  if selected_request.status not in ('published', 'under_review', 'quotes_received') then
    raise exception 'This repair request cannot accept a quote.' using errcode = '23514';
  end if;

  update public.quotes
  set status = 'rejected', rejected_at = now(), updated_at = now()
  where request_id = selected_request.id
    and id <> selected_quote.id
    and status = 'submitted'
    and deleted_at is null;

  update public.quotes
  set status = 'accepted', accepted_at = now(), updated_at = now()
  where id = selected_quote.id;

  update public.repair_requests
  set status = 'quote_accepted', updated_at = now()
  where id = selected_request.id;

  initial_status := case
    when selected_request.inspection_required then 'inspection_requested'::public.job_status
    else 'repair_scheduled'::public.job_status
  end;

  insert into public.jobs (
    request_id,
    accepted_quote_id,
    customer_id,
    repairer_id,
    status,
    agreed_minimum_minor,
    agreed_maximum_minor,
    currency_code
  ) values (
    selected_request.id,
    selected_quote.id,
    selected_request.customer_id,
    selected_quote.repairer_id,
    initial_status,
    selected_quote.total_minimum_minor,
    selected_quote.total_maximum_minor,
    selected_quote.currency_code
  ) returning id into new_job_id;

  update public.conversations
  set job_id = new_job_id, updated_at = now()
  where id = private.ensure_conversation(selected_request.id, selected_quote.repairer_id);

  insert into public.idempotency_keys (
    user_id,
    scope,
    idempotency_key,
    resource_type,
    resource_id,
    result
  ) values (
    caller_id,
    'accept_quote',
    accept_quote.idempotency_key,
    'job',
    new_job_id,
    jsonb_build_object('job_id', new_job_id)
  );

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    caller_id,
    'quote.accepted',
    'job',
    new_job_id,
    jsonb_build_object('quote_id', selected_quote.id, 'request_id', selected_request.id)
  );
  return new_job_id;
end;
$$;

create or replace function public.set_job_status(
  job_id uuid,
  new_status public.job_status,
  reason text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  target_job public.jobs%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  select * into target_job from public.jobs as j where j.id = job_id for update;
  if not found or target_job.deleted_at is not null then
    raise exception 'Job not found.' using errcode = 'P0002';
  end if;
  if caller_id not in (target_job.customer_id, target_job.repairer_id) then
    raise exception 'Only job participants can change its status.' using errcode = '42501';
  end if;

  if caller_id = target_job.customer_id then
    if new_status = 'completed'
      and target_job.status not in ('repair_in_progress', 'waiting_for_parts', 'ready_for_collection') then
      raise exception 'The job is not ready to be marked complete.' using errcode = '23514';
    elsif new_status = 'cancelled'
      and target_job.status not in ('inspection_requested', 'inspection_booked', 'repair_scheduled') then
      raise exception 'This job can no longer be cancelled directly.' using errcode = '23514';
    elsif new_status not in ('completed', 'cancelled', 'disputed') then
      raise exception 'Customers cannot apply that job status.' using errcode = '42501';
    end if;
  else
    if new_status not in (
      'inspection_booked',
      'repair_scheduled',
      'repair_in_progress',
      'waiting_for_parts',
      'ready_for_collection',
      'cancelled',
      'disputed'
    ) then
      raise exception 'Repairers cannot apply that job status.' using errcode = '42501';
    end if;
  end if;

  perform set_config('fixbrief.status_reason', left(coalesce(reason, ''), 2000), true);
  update public.jobs set status = new_status, updated_at = now() where id = job_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    caller_id,
    'job.status_changed',
    'job',
    job_id,
    jsonb_build_object('from', target_job.status, 'to', new_status)
  );
end;
$$;

revoke all on function public.claim_role(text) from public, anon;
revoke all on function public.claim_user_role(public.app_user_role) from public, anon;
revoke all on function public.complete_customer_onboarding(jsonb) from public, anon;
revoke all on function public.submit_repairer_onboarding(jsonb) from public, anon;
revoke all on function public.authorise_contact(uuid, uuid) from public, anon;
revoke all on function public.accept_quote(uuid, text) from public, anon;
revoke all on function public.set_job_status(uuid, public.job_status, text) from public, anon;

grant execute on function public.claim_role(text) to authenticated;
grant execute on function public.claim_user_role(public.app_user_role) to authenticated;
grant execute on function public.complete_customer_onboarding(jsonb) to authenticated;
grant execute on function public.submit_repairer_onboarding(jsonb) to authenticated;
grant execute on function public.authorise_contact(uuid, uuid) to authenticated;
grant execute on function public.accept_quote(uuid, text) to authenticated;
grant execute on function public.set_job_status(uuid, public.job_status, text) to authenticated;

revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_user_role() to authenticated;
grant execute on function private.can_view_marketplace_request(uuid, uuid) to authenticated;
grant execute on function private.can_access_conversation(uuid, uuid) to authenticated;
grant execute on function private.can_access_private_location(uuid, uuid) to authenticated;
grant execute on function private.can_access_request_evidence(uuid, uuid) to authenticated;

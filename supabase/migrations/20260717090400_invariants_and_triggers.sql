-- FixBrief Stage 4: reusable helper functions and database-enforced invariants.

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.current_user_role()
returns public.app_user_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.role
  from public.profiles as p
  where p.id = (select auth.uid())
    and p.account_status = 'active'
    and p.deleted_at is null
$$;

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_auth_user();

-- Backfill profiles safely if this migration is applied to a project that already
-- contains Auth users.
insert into public.profiles (id, display_name)
select
  u.id,
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', '')), '')
from auth.users as u
on conflict (id) do nothing;

create or replace function private.protect_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if current_user in ('anon', 'authenticated') and (
    new.role is distinct from old.role
    or new.onboarding_status is distinct from old.onboarding_status
    or new.account_status is distinct from old.account_status
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise exception 'Privileged profile fields can only be changed by a controlled function.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_profile_privileged_columns
  before update on public.profiles
  for each row execute function private.protect_profile_privileged_columns();

create or replace function private.protect_repairer_privileged_columns()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if current_user in ('anon', 'authenticated') and (
    new.verification_status is distinct from old.verification_status
    or new.verified_at is distinct from old.verified_at
    or new.verified_by is distinct from old.verified_by
    or new.verification_notes is distinct from old.verification_notes
    or new.is_marketplace_visible is distinct from old.is_marketplace_visible
    or new.average_rating is distinct from old.average_rating
    or new.review_count is distinct from old.review_count
    or new.completed_job_count is distinct from old.completed_job_count
    or new.response_rate is distinct from old.response_rate
    or new.quote_acceptance_rate is distinct from old.quote_acceptance_rate
  ) then
    raise exception 'Verification and marketplace metrics are server controlled.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_repairer_privileged_columns
  before update on public.repairer_profiles
  for each row execute function private.protect_repairer_privileged_columns();

create or replace function private.protect_certification_verification()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if current_user in ('anon', 'authenticated') and (
    new.repairer_id is distinct from old.repairer_id
    or new.verification_status is distinct from old.verification_status
    or new.verified_at is distinct from old.verified_at
    or new.verified_by is distinct from old.verified_by
  ) then
    raise exception 'Certification verification is server controlled.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_certification_verification
  before update on public.repairer_certifications
  for each row execute function private.protect_certification_verification();

create or replace function private.require_customer_role()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.profiles as p
    where p.id = new.user_id
      and p.role = 'customer'
      and p.account_status = 'active'
      and p.deleted_at is null
  ) then
    raise exception 'A customer profile requires an active customer role.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger require_customer_role
  before insert or update of user_id on public.customer_profiles
  for each row execute function private.require_customer_role();

create or replace function private.require_repairer_role()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.profiles as p
    where p.id = new.user_id
      and p.role = 'repairer'
      and p.account_status = 'active'
      and p.deleted_at is null
  ) then
    raise exception 'A repairer profile requires an active repairer role.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger require_repairer_role
  before insert or update of user_id on public.repairer_profiles
  for each row execute function private.require_repairer_role();

create or replace function private.validate_specialisation_category()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.subcategory_id is not null and not exists (
    select 1
    from public.repair_subcategories as s
    where s.id = new.subcategory_id
      and s.category_id = new.category_id
      and s.deleted_at is null
  ) then
    raise exception 'The selected subcategory does not belong to the category.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_specialisation_category
  before insert or update of category_id, subcategory_id
  on public.repairer_specialisations
  for each row execute function private.validate_specialisation_category();

create or replace function private.validate_request_category()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.subcategory_id is not null and not exists (
    select 1
    from public.repair_subcategories as s
    where s.id = new.subcategory_id
      and s.category_id = new.category_id
      and s.deleted_at is null
      and s.is_active
  ) then
    raise exception 'The selected subcategory does not belong to the category.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_request_category
  before insert or update of category_id, subcategory_id
  on public.repair_requests
  for each row execute function private.validate_request_category();

create or replace function private.validate_private_location_owner()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.repair_requests as r
    where r.id = new.request_id and r.customer_id = new.customer_id
  ) then
    raise exception 'Private location ownership must match the repair request.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_private_location_owner
  before insert or update of request_id, customer_id
  on public.repair_request_private_locations
  for each row execute function private.validate_private_location_owner();

create or replace function private.validate_request_transition()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  transition_allowed boolean;
begin
  if tg_op = 'INSERT' then
    if current_user in ('anon', 'authenticated') then
      new.version := 1;
      new.published_at := null;
      new.cancelled_at := null;
      new.deleted_at := null;
    end if;
    return new;
  end if;

  if new.customer_id is distinct from old.customer_id then
    raise exception 'Repair request ownership cannot be changed.' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    transition_allowed := case old.status
      when 'draft' then new.status in ('submitted', 'cancelled')
      when 'submitted' then new.status in ('assessment_complete', 'cancelled')
      when 'assessment_complete' then new.status in ('submitted', 'published', 'cancelled')
      when 'published' then new.status in ('under_review', 'quotes_received', 'quote_accepted', 'cancelled', 'archived')
      when 'under_review' then new.status in ('published', 'quotes_received', 'quote_accepted', 'cancelled', 'archived')
      when 'quotes_received' then new.status in ('under_review', 'quote_accepted', 'cancelled', 'archived')
      when 'quote_accepted' then new.status = 'archived'
      when 'cancelled' then new.status = 'archived'
      when 'archived' then false
    end;

    if not coalesce(transition_allowed, false) then
      raise exception 'Invalid repair request transition from % to %.', old.status, new.status
        using errcode = '23514';
    end if;

    if new.status in ('published', 'under_review', 'quotes_received', 'quote_accepted') then
      if new.category_id is null
        or nullif(btrim(new.item_name), '') is null
        or nullif(btrim(new.problem_description), '') is null
        or nullif(btrim(new.approximate_area), '') is null then
        raise exception 'Published requests require a category, item, description, and approximate area.'
          using errcode = '23514';
      end if;
      new.published_at := coalesce(new.published_at, now());
    end if;

    if new.status = 'cancelled' then
      new.cancelled_at := coalesce(new.cancelled_at, now());
    end if;
  end if;

  new.version := old.version + 1;
  return new;
end;
$$;

create trigger validate_request_transition
  before update on public.repair_requests
  for each row execute function private.validate_request_transition();

create or replace function private.calculate_quote_totals()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  item_minimum bigint := 0;
  item_maximum bigint := 0;
begin
  select
    coalesce(sum(i.minimum_minor), 0),
    coalesce(sum(i.maximum_minor), 0)
  into item_minimum, item_maximum
  from public.quote_items as i
  where i.quote_id = new.id and i.deleted_at is null;

  new.total_minimum_minor :=
    new.inspection_fee_minor
    + new.callout_fee_minor
    + new.labour_minimum_minor
    + new.parts_minimum_minor
    + new.other_charges_minimum_minor
    + item_minimum;
  new.total_maximum_minor :=
    new.inspection_fee_minor
    + new.callout_fee_minor
    + new.labour_maximum_minor
    + new.parts_maximum_minor
    + new.other_charges_maximum_minor
    + item_maximum;
  return new;
end;
$$;

create trigger calculate_quote_totals
  before insert or update of
    inspection_fee_minor,
    callout_fee_minor,
    labour_minimum_minor,
    labour_maximum_minor,
    parts_minimum_minor,
    parts_maximum_minor,
    other_charges_minimum_minor,
    other_charges_maximum_minor,
    total_minimum_minor,
    total_maximum_minor
  on public.quotes
  for each row execute function private.calculate_quote_totals();

create or replace function private.recalculate_quote_after_item()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_quote_id uuid;
begin
  target_quote_id := case when tg_op = 'DELETE' then old.quote_id else new.quote_id end;
  update public.quotes as q
  set
    total_minimum_minor = q.total_minimum_minor,
    total_maximum_minor = q.total_maximum_minor,
    updated_at = now()
  where q.id = target_quote_id;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger recalculate_quote_after_item
  after insert or update or delete on public.quote_items
  for each row execute function private.recalculate_quote_after_item();

create or replace function private.validate_quote_transition()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  transition_allowed boolean;
begin
  if tg_op = 'UPDATE' then
    if new.request_id is distinct from old.request_id
      or new.repairer_id is distinct from old.repairer_id then
      raise exception 'Quote ownership and request cannot be changed.' using errcode = '42501';
    end if;

    if new.status is distinct from old.status then
      transition_allowed := case old.status
        when 'draft' then new.status in ('submitted', 'withdrawn')
        when 'submitted' then new.status in ('accepted', 'rejected', 'withdrawn', 'expired')
        when 'accepted' then false
        when 'rejected' then false
        when 'withdrawn' then false
        when 'expired' then false
      end;
      if not coalesce(transition_allowed, false) then
        raise exception 'Invalid quote transition from % to %.', old.status, new.status
          using errcode = '23514';
      end if;
    end if;
  end if;

  if new.status = 'submitted' then
    new.submitted_at := coalesce(new.submitted_at, now());
    if new.expires_at is null or new.expires_at <= now() then
      raise exception 'Submitted quotes require a future expiry time.' using errcode = '23514';
    end if;
  elsif new.status = 'accepted' then
    new.accepted_at := coalesce(new.accepted_at, now());
  elsif new.status = 'rejected' then
    new.rejected_at := coalesce(new.rejected_at, now());
  elsif new.status = 'withdrawn' then
    new.withdrawn_at := coalesce(new.withdrawn_at, now());
  end if;
  return new;
end;
$$;

create trigger validate_quote_transition
  before insert or update on public.quotes
  for each row execute function private.validate_quote_transition();

create or replace function private.validate_job_transition()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  transition_allowed boolean;
begin
  if tg_op = 'INSERT' then
    return new;
  end if;

  if new.request_id is distinct from old.request_id
    or new.accepted_quote_id is distinct from old.accepted_quote_id
    or new.customer_id is distinct from old.customer_id
    or new.repairer_id is distinct from old.repairer_id then
    raise exception 'Job parties and source records cannot be changed.' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    transition_allowed := case old.status
      when 'inspection_requested' then new.status in ('inspection_booked', 'cancelled', 'disputed')
      when 'inspection_booked' then new.status in ('repair_scheduled', 'cancelled', 'disputed')
      when 'repair_scheduled' then new.status in ('repair_in_progress', 'cancelled', 'disputed')
      when 'repair_in_progress' then new.status in ('waiting_for_parts', 'ready_for_collection', 'completed', 'cancelled', 'disputed')
      when 'waiting_for_parts' then new.status in ('repair_in_progress', 'ready_for_collection', 'completed', 'cancelled', 'disputed')
      when 'ready_for_collection' then new.status in ('repair_in_progress', 'completed', 'disputed')
      when 'completed' then new.status = 'disputed'
      when 'cancelled' then new.status = 'disputed'
      when 'disputed' then new.status in ('repair_in_progress', 'completed', 'cancelled')
    end;
    if not coalesce(transition_allowed, false) then
      raise exception 'Invalid job transition from % to %.', old.status, new.status
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'completed' then
    new.completed_at := coalesce(new.completed_at, now());
  elsif new.status = 'cancelled' then
    new.cancelled_at := coalesce(new.cancelled_at, now());
  elsif new.status = 'disputed' then
    new.disputed_at := coalesce(new.disputed_at, now());
  end if;
  return new;
end;
$$;

create trigger validate_job_transition
  before update on public.jobs
  for each row execute function private.validate_job_transition();

create or replace function private.record_job_status_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.job_status_history (
      job_id,
      from_status,
      to_status,
      changed_by,
      reason
    ) values (
      new.id,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      (select auth.uid()),
      nullif(current_setting('fixbrief.status_reason', true), '')
    );
  end if;
  return new;
end;
$$;

create trigger record_job_status_change
  after insert or update of status on public.jobs
  for each row execute function private.record_job_status_change();

create or replace function private.enforce_review_eligibility()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_job public.jobs%rowtype;
begin
  select * into target_job
  from public.jobs as j
  where j.id = new.job_id and j.deleted_at is null;

  if not found or target_job.status <> 'completed' then
    raise exception 'Reviews are available only after a completed job.' using errcode = '23514';
  end if;

  if new.direction = 'customer_to_repairer' then
    if new.author_id <> target_job.customer_id or new.reviewed_user_id <> target_job.repairer_id then
      raise exception 'Review participants do not match the completed job.' using errcode = '23514';
    end if;
  else
    if new.author_id <> target_job.repairer_id or new.reviewed_user_id <> target_job.customer_id then
      raise exception 'Review participants do not match the completed job.' using errcode = '23514';
    end if;
  end if;

  if tg_op = 'UPDATE' and (
    new.job_id is distinct from old.job_id
    or new.author_id is distinct from old.author_id
    or new.reviewed_user_id is distinct from old.reviewed_user_id
    or new.direction is distinct from old.direction
  ) then
    raise exception 'Review ownership and direction cannot be changed.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger enforce_review_eligibility
  before insert or update on public.reviews
  for each row execute function private.enforce_review_eligibility();

create or replace function private.recalculate_repairer_rating()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_repairer uuid;
begin
  target_repairer := case
    when tg_op = 'DELETE' then old.reviewed_user_id
    else new.reviewed_user_id
  end;

  if coalesce(case when tg_op = 'DELETE' then old.direction else new.direction end, 'repairer_to_customer')
    = 'customer_to_repairer' then
    update public.repairer_profiles as rp
    set
      average_rating = coalesce((
        select round(avg(r.overall_rating)::numeric, 2)
        from public.reviews as r
        where r.reviewed_user_id = target_repairer
          and r.direction = 'customer_to_repairer'
          and r.deleted_at is null
      ), 0),
      review_count = (
        select count(*)::integer
        from public.reviews as r
        where r.reviewed_user_id = target_repairer
          and r.direction = 'customer_to_repairer'
          and r.deleted_at is null
      ),
      updated_at = now()
    where rp.user_id = target_repairer;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger recalculate_repairer_rating
  after insert or update or delete on public.reviews
  for each row execute function private.recalculate_repairer_rating();

create or replace function private.validate_message_sender()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  other_user uuid;
begin
  if not exists (
    select 1
    from public.conversation_participants as cp
    where cp.conversation_id = new.conversation_id
      and cp.participant_id = new.sender_id
      and cp.left_at is null
  ) then
    raise exception 'The sender is not an active conversation participant.' using errcode = '42501';
  end if;

  select cp.participant_id into other_user
  from public.conversation_participants as cp
  where cp.conversation_id = new.conversation_id
    and cp.participant_id <> new.sender_id
    and cp.left_at is null
  limit 1;

  if other_user is not null and exists (
    select 1 from public.blocked_users as b
    where (b.blocker_id = new.sender_id and b.blocked_id = other_user)
       or (b.blocker_id = other_user and b.blocked_id = new.sender_id)
  ) then
    raise exception 'Messages cannot be sent between blocked users.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger validate_message_sender
  before insert on public.messages
  for each row execute function private.validate_message_sender();

create or replace function private.protect_appointment_location_release()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  job_customer_id uuid;
begin
  if tg_op = 'UPDATE'
    and new.location_released
    and new.location_released is distinct from old.location_released then
    select j.customer_id into job_customer_id
    from public.jobs as j where j.id = new.job_id;
    if current_user = 'authenticated' and (select auth.uid()) <> job_customer_id then
      raise exception 'Only the customer can release an appointment location.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_appointment_location_release
  before update on public.appointments
  for each row execute function private.protect_appointment_location_release();

create or replace function private.touch_conversation_after_message()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at, updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

create trigger touch_conversation_after_message
  after insert on public.messages
  for each row execute function private.touch_conversation_after_message();

-- Apply updated_at consistently to mutable tables.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'customer_profiles',
    'repairer_profiles',
    'repair_categories',
    'repair_subcategories',
    'repairer_specialisations',
    'repairer_certifications',
    'service_areas',
    'availability_slots',
    'repair_requests',
    'repair_request_private_locations',
    'repair_request_symptoms',
    'repair_request_media',
    'ai_follow_up_questions',
    'quotes',
    'quote_items',
    'jobs',
    'appointments',
    'conversations',
    'conversation_participants',
    'messages',
    'reviews',
    'reports'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute function private.set_updated_at()',
      table_name
    );
  end loop;
end;
$$;

revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_user_role() to authenticated;

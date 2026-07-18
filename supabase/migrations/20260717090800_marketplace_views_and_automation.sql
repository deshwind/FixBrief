-- FixBrief Stage 4: privacy-safe API projections, matching RPCs, verification
-- workflow, notifications, derived job metrics, and scoped Realtime tables.

create view public.public_repairer_profiles
with (security_invoker = true, security_barrier = true)
as
select
  rp.user_id,
  rp.full_name,
  rp.business_name,
  rp.logo_path,
  rp.business_description,
  rp.years_experience,
  rp.qualifications,
  rp.inspection_fee_minor,
  rp.currency_code,
  rp.service_radius_kilometres,
  rp.working_hours,
  rp.emergency_service_available,
  rp.mobile_repair_available,
  rp.collection_service_available,
  rp.verification_status,
  rp.verified_at,
  rp.average_rating,
  rp.review_count,
  rp.completed_job_count,
  rp.response_rate,
  rp.quote_acceptance_rate,
  rp.created_at,
  rp.updated_at
from public.repairer_profiles as rp
where rp.is_marketplace_visible
  and rp.verification_status = 'verified'
  and rp.deleted_at is null;

create view public.marketplace_repair_requests
with (security_invoker = true, security_barrier = true)
as
select
  r.id,
  r.category_id,
  r.subcategory_id,
  r.item_name,
  r.brand,
  r.model,
  r.approximate_age_years,
  r.vehicle_make,
  r.vehicle_model,
  r.vehicle_year,
  r.problem_description,
  r.structured_brief,
  r.preferred_repair_date,
  r.preferred_time_start,
  r.preferred_time_end,
  r.urgency,
  r.approximate_area,
  r.travel_distance_kilometres,
  r.collection_required,
  r.mobile_repair_required,
  r.inspection_required,
  r.maximum_callout_fee_minor,
  r.budget_minimum_minor,
  r.budget_maximum_minor,
  r.currency_code,
  r.status,
  r.published_at,
  r.created_at,
  r.updated_at
from public.repair_requests as r
where r.status in ('published', 'under_review', 'quotes_received')
  and r.deleted_at is null;

grant select on public.public_repairer_profiles to authenticated;
grant select on public.marketplace_repair_requests to authenticated;

create or replace function public.get_own_repairer_profile()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select to_jsonb(rp)
    - 'verified_by'
    - 'verification_notes'
  from public.repairer_profiles as rp
  where rp.user_id = (select auth.uid())
    and rp.deleted_at is null
$$;

create or replace function public.get_matching_requests(
  category_filter uuid default null,
  urgency_filter public.urgency_level default null,
  result_limit integer default 50
)
returns setof public.marketplace_repair_requests
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select request_view.*
  from public.marketplace_repair_requests as request_view
  where (category_filter is null or request_view.category_id = category_filter)
    and (urgency_filter is null or request_view.urgency = urgency_filter)
    and private.can_view_marketplace_request(request_view.id, (select auth.uid()))
  order by
    case request_view.urgency
      when 'emergency' then 1
      when 'asap' then 2
      when 'within_24_hours' then 3
      when 'within_3_days' then 4
      when 'within_1_week' then 5
      else 6
    end,
    request_view.published_at desc
  limit least(greatest(coalesce(result_limit, 50), 1), 100)
$$;

create or replace function public.get_matching_repairers(
  category_filter uuid,
  subcategory_filter uuid default null,
  result_limit integer default 50
)
returns setof public.public_repairer_profiles
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select distinct repairer_view.*
  from public.public_repairer_profiles as repairer_view
  join public.repairer_specialisations as rs
    on rs.repairer_id = repairer_view.user_id
  where rs.category_id = category_filter
    and rs.deleted_at is null
    and (
      subcategory_filter is null
      or rs.subcategory_id is null
      or rs.subcategory_id = subcategory_filter
    )
  order by repairer_view.average_rating desc, repairer_view.review_count desc
  limit least(greatest(coalesce(result_limit, 50), 1), 100)
$$;

create or replace function public.set_repairer_verification(
  repairer_id uuid,
  new_status public.verification_status,
  review_notes text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'Repairer verification requires a trusted backend.' using errcode = '42501';
  end if;
  if new_status not in ('verified', 'rejected', 'suspended') then
    raise exception 'The requested verification state is not reviewable.' using errcode = '22023';
  end if;

  update public.repairer_profiles
  set
    verification_status = new_status,
    verified_at = case when new_status = 'verified' then now() else null end,
    verified_by = (select auth.uid()),
    verification_notes = left(review_notes, 5000),
    is_marketplace_visible = new_status = 'verified',
    updated_at = now()
  where user_id = repairer_id and deleted_at is null;

  if not found then
    raise exception 'Repairer profile not found.' using errcode = 'P0002';
  end if;

  update public.profiles
  set
    onboarding_status = case
      when new_status = 'verified' then 'approved'::public.onboarding_status
      else 'rejected'::public.onboarding_status
    end,
    updated_at = now()
  where id = repairer_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    (select auth.uid()),
    'repairer.verification_changed',
    'repairer_profile',
    repairer_id,
    jsonb_build_object('status', new_status)
  );
end;
$$;

create or replace function private.recalculate_completed_job_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    update public.repairer_profiles as rp
    set
      completed_job_count = (
        select count(*)::integer
        from public.jobs as j
        where j.repairer_id = new.repairer_id
          and j.status = 'completed'
          and j.deleted_at is null
      ),
      updated_at = now()
    where rp.user_id = new.repairer_id;
  end if;
  return new;
end;
$$;

create trigger recalculate_completed_job_count
  after insert or update of status on public.jobs
  for each row execute function private.recalculate_completed_job_count();

create or replace function private.notify_quote_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  request_customer_id uuid;
begin
  select r.customer_id into request_customer_id
  from public.repair_requests as r where r.id = new.request_id;

  if new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    insert into public.notifications (
      recipient_id,
      notification_type,
      title,
      body,
      related_entity_type,
      related_entity_id,
      deep_link,
      dedupe_key
    ) values (
      request_customer_id,
      'new_quote',
      'New provisional quote',
      'A repair professional has submitted a provisional estimate.',
      'quote',
      new.id,
      '/customer/requests/' || new.request_id::text || '/quotes/' || new.id::text,
      'quote-submitted:' || new.id::text
    ) on conflict do nothing;
  elsif new.status = 'accepted'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    insert into public.notifications (
      recipient_id,
      notification_type,
      title,
      body,
      related_entity_type,
      related_entity_id,
      deep_link,
      dedupe_key
    ) values (
      new.repairer_id,
      'quote_accepted',
      'Your quote was accepted',
      'The customer accepted your provisional quote.',
      'quote',
      new.id,
      '/repairer/quotes/' || new.id::text,
      'quote-accepted:' || new.id::text
    ) on conflict do nothing;
  elsif new.status = 'rejected'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    insert into public.notifications (
      recipient_id,
      notification_type,
      title,
      body,
      related_entity_type,
      related_entity_id,
      deep_link,
      dedupe_key
    ) values (
      new.repairer_id,
      'quote_rejected',
      'Quote not selected',
      'The customer selected another option for this request.',
      'quote',
      new.id,
      '/repairer/quotes/' || new.id::text,
      'quote-rejected:' || new.id::text
    ) on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger notify_quote_change
  after insert or update of status on public.quotes
  for each row execute function private.notify_quote_change();

create or replace function private.mark_request_quotes_received()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    update public.repair_requests
    set status = 'quotes_received', updated_at = now()
    where id = new.request_id
      and status in ('published', 'under_review')
      and deleted_at is null;
  end if;
  return new;
end;
$$;

create trigger mark_request_quotes_received
  after insert or update of status on public.quotes
  for each row execute function private.mark_request_quotes_received();

create or replace function private.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.notifications (
    recipient_id,
    notification_type,
    title,
    body,
    related_entity_type,
    related_entity_id,
    deep_link,
    dedupe_key
  )
  select
    cp.participant_id,
    'new_message',
    'New message',
    case when new.body is null then 'You received an attachment.' else left(new.body, 160) end,
    'conversation',
    new.conversation_id,
    '/messages/' || new.conversation_id::text,
    'message:' || new.id::text || ':' || cp.participant_id::text
  from public.conversation_participants as cp
  where cp.conversation_id = new.conversation_id
    and cp.participant_id <> new.sender_id
    and cp.left_at is null
  on conflict do nothing;
  return new;
end;
$$;

create trigger notify_new_message
  after insert on public.messages
  for each row execute function private.notify_new_message();

create or replace function private.notify_job_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  recipient uuid;
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    recipient := case
      when (select auth.uid()) = new.customer_id then new.repairer_id
      else new.customer_id
    end;
    insert into public.notifications (
      recipient_id,
      notification_type,
      title,
      body,
      related_entity_type,
      related_entity_id,
      deep_link,
      dedupe_key
    ) values (
      recipient,
      case when new.status = 'completed' then 'repair_completed' else 'job_status_updated' end,
      case when new.status = 'completed' then 'Repair marked complete' else 'Job status updated' end,
      'The job is now ' || replace(new.status::text, '_', ' ') || '.',
      'job',
      new.id,
      case
        when recipient = new.customer_id then '/customer/jobs/' || new.id::text
        else '/repairer/jobs/' || new.id::text
      end,
      'job-status:' || new.id::text || ':' || new.status::text || ':' || recipient::text
    ) on conflict do nothing;

    if new.status = 'completed' then
      insert into public.notifications (
        recipient_id,
        notification_type,
        title,
        body,
        related_entity_type,
        related_entity_id,
        deep_link,
        dedupe_key
      ) values
        (
          new.customer_id,
          'review_requested',
          'How did the repair go?',
          'Share a review of the repair professional after this completed job.',
          'job',
          new.id,
          '/customer/jobs/' || new.id::text || '/review',
          'review-request:' || new.id::text || ':' || new.customer_id::text
        ),
        (
          new.repairer_id,
          'review_requested',
          'Share customer feedback',
          'You can now review the customer for this completed job.',
          'job',
          new.id,
          '/repairer/jobs/' || new.id::text,
          'review-request:' || new.id::text || ':' || new.repairer_id::text
        )
      on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

create trigger notify_job_status
  after insert or update of status on public.jobs
  for each row execute function private.notify_job_status();

revoke all on function public.get_own_repairer_profile() from public, anon;
revoke all on function public.get_matching_requests(uuid, public.urgency_level, integer) from public, anon;
revoke all on function public.get_matching_repairers(uuid, uuid, integer) from public, anon;
revoke all on function public.set_repairer_verification(uuid, public.verification_status, text)
  from public, anon, authenticated;
grant execute on function public.get_own_repairer_profile() to authenticated;
grant execute on function public.get_matching_requests(uuid, public.urgency_level, integer) to authenticated;
grant execute on function public.get_matching_repairers(uuid, uuid, integer) to authenticated;
grant execute on function public.set_repairer_verification(uuid, public.verification_status, text)
  to service_role;

alter table public.messages replica identity full;
alter table public.notifications replica identity full;
alter table public.appointments replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.messages;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.notifications;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.appointments;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.job_status_history;
    exception when duplicate_object then null;
    end;
  end if;
end;
$$;

-- Trigger functions remain private. Only pure predicates needed by RLS and
-- Storage are executable by the authenticated database role.
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_user_role() to authenticated;
grant execute on function private.can_view_marketplace_request(uuid, uuid) to authenticated;
grant execute on function private.can_access_conversation(uuid, uuid) to authenticated;
grant execute on function private.can_access_private_location(uuid, uuid) to authenticated;
grant execute on function private.can_access_request_evidence(uuid, uuid) to authenticated;
grant execute on function private.storage_owner_id(text) to authenticated;
grant execute on function private.storage_related_id(text) to authenticated;
grant execute on function private.can_access_storage_object(text, text, uuid) to authenticated;

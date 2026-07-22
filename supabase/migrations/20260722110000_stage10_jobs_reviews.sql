-- FixBrief Stage 10: participant-scoped job tracking, status history, and
-- reciprocal post-completion reviews.

create or replace function private.job_review_json(target_review public.reviews)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'id', target_review.id,
    'job_id', target_review.job_id,
    'author_id', target_review.author_id,
    'reviewed_user_id', target_review.reviewed_user_id,
    'direction', target_review.direction,
    'overall_rating', target_review.overall_rating,
    'quality_rating', target_review.quality_rating,
    'communication_rating', target_review.communication_rating,
    'punctuality_rating', target_review.punctuality_rating,
    'value_rating', target_review.value_rating,
    'quote_accuracy_rating', target_review.quote_accuracy_rating,
    'description_accuracy_rating', target_review.description_accuracy_rating,
    'attendance_rating', target_review.attendance_rating,
    'location_accessibility_rating', target_review.location_accessibility_rating,
    'comment', target_review.comment,
    'repairer_response', target_review.repairer_response,
    'responded_at', target_review.responded_at,
    'author_name', coalesce(
      (
        select coalesce(
          rp.business_name,
          cp.full_name,
          rp.full_name,
          p.display_name
        )
        from public.profiles as p
        left join public.customer_profiles as cp on cp.user_id = p.id
        left join public.repairer_profiles as rp on rp.user_id = p.id
        where p.id = target_review.author_id
      ),
      'FixBrief member'
    ),
    'created_at', target_review.created_at
  );
$$;

create or replace function private.job_json(
  target_job public.jobs,
  viewer_id uuid,
  include_details boolean default true
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'id', target_job.id,
    'request_id', target_job.request_id,
    'accepted_quote_id', target_job.accepted_quote_id,
    'customer_id', target_job.customer_id,
    'repairer_id', target_job.repairer_id,
    'item_name', coalesce(rr.item_name, 'Repair job'),
    'counterpart_name', case
      when viewer_id = target_job.customer_id then
        coalesce(rp.business_name, rp.full_name, repairer_user.display_name, 'Repair professional')
      else
        coalesce(cp.full_name, customer_user.display_name, 'Customer')
    end,
    'business_name', rp.business_name,
    'approximate_area', rr.approximate_area,
    'status', target_job.status,
    'agreed_minimum_minor', target_job.agreed_minimum_minor,
    'agreed_maximum_minor', target_job.agreed_maximum_minor,
    'currency_code', target_job.currency_code,
    'accepted_at', target_job.accepted_at,
    'completed_at', target_job.completed_at,
    'cancelled_at', target_job.cancelled_at,
    'cancellation_reason', target_job.cancellation_reason,
    'disputed_at', target_job.disputed_at,
    'dispute_reason', target_job.dispute_reason,
    'updated_at', target_job.updated_at,
    'history', case when include_details then coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', h.id,
            'from_status', h.from_status,
            'to_status', h.to_status,
            'changed_by', h.changed_by,
            'reason', h.reason,
            'created_at', h.created_at
          ) order by h.created_at
        )
        from public.job_status_history as h
        where h.job_id = target_job.id
      ),
      '[]'::jsonb
    ) else '[]'::jsonb end,
    'reviews', case when include_details then coalesce(
      (
        select jsonb_agg(private.job_review_json(r) order by r.created_at)
        from public.reviews as r
        where r.job_id = target_job.id and r.deleted_at is null
      ),
      '[]'::jsonb
    ) else '[]'::jsonb end,
    'has_my_review', exists (
      select 1
      from public.reviews as own_review
      where own_review.job_id = target_job.id
        and own_review.author_id = viewer_id
        and own_review.deleted_at is null
    )
  )
  from public.repair_requests as rr
  join public.profiles as customer_user on customer_user.id = target_job.customer_id
  join public.profiles as repairer_user on repairer_user.id = target_job.repairer_id
  left join public.customer_profiles as cp on cp.user_id = target_job.customer_id
  left join public.repairer_profiles as rp on rp.user_id = target_job.repairer_id
  where rr.id = target_job.request_id;
$$;

create or replace function public.get_jobs()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        private.job_json(j, caller_id, false)
        order by (j.status in ('completed', 'cancelled')), j.updated_at desc
      )
      from public.jobs as j
      where j.deleted_at is null
        and caller_id in (j.customer_id, j.repairer_id)
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.get_job_details(target_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  target_job public.jobs%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select * into target_job
  from public.jobs as j
  where j.id = target_job_id
    and j.deleted_at is null
    and caller_id in (j.customer_id, j.repairer_id);

  if not found then
    raise exception 'Job not found.' using errcode = 'P0002';
  end if;
  return private.job_json(target_job, caller_id, true);
end;
$$;

create or replace function public.submit_job_review(
  target_job_id uuid,
  review_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  target_job public.jobs%rowtype;
  new_review public.reviews%rowtype;
  review_direction public.review_direction;
  reviewed_id uuid;
  overall_value smallint;
  communication_value smallint;
  quality_value smallint;
  punctuality_value smallint;
  value_value smallint;
  quote_accuracy_value smallint;
  description_accuracy_value smallint;
  attendance_value smallint;
  location_accessibility_value smallint;
  comment_value text;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if review_payload is null or jsonb_typeof(review_payload) <> 'object' then
    raise exception 'Review details must be an object.' using errcode = '22023';
  end if;

  select * into target_job
  from public.jobs as j
  where j.id = target_job_id
    and j.deleted_at is null
    and caller_id in (j.customer_id, j.repairer_id)
  for update;

  if not found then
    raise exception 'Job not found.' using errcode = 'P0002';
  end if;
  if target_job.status <> 'completed' then
    raise exception 'Reviews are available only after a completed job.' using errcode = '23514';
  end if;

  overall_value := (review_payload ->> 'overall_rating')::smallint;
  communication_value := (review_payload ->> 'communication_rating')::smallint;
  quality_value := (review_payload ->> 'quality_rating')::smallint;
  punctuality_value := (review_payload ->> 'punctuality_rating')::smallint;
  value_value := (review_payload ->> 'value_rating')::smallint;
  quote_accuracy_value := (review_payload ->> 'quote_accuracy_rating')::smallint;
  description_accuracy_value := (review_payload ->> 'description_accuracy_rating')::smallint;
  attendance_value := (review_payload ->> 'attendance_rating')::smallint;
  location_accessibility_value := (review_payload ->> 'location_accessibility_rating')::smallint;
  comment_value := nullif(trim(review_payload ->> 'comment'), '');

  if overall_value is null or communication_value is null
    or overall_value not between 1 and 5
    or communication_value not between 1 and 5 then
    raise exception 'Overall and communication ratings must be between 1 and 5.' using errcode = '22023';
  end if;
  if comment_value is not null and char_length(comment_value) > 5000 then
    raise exception 'Review comments must be under 5,000 characters.' using errcode = '22023';
  end if;

  if caller_id = target_job.customer_id then
    review_direction := 'customer_to_repairer';
    reviewed_id := target_job.repairer_id;
    if quality_value is null or punctuality_value is null or value_value is null
      or quote_accuracy_value is null then
      raise exception 'Complete every customer review rating.' using errcode = '22023';
    end if;
    description_accuracy_value := null;
    attendance_value := null;
    location_accessibility_value := null;
  else
    review_direction := 'repairer_to_customer';
    reviewed_id := target_job.customer_id;
    if description_accuracy_value is null or attendance_value is null
      or location_accessibility_value is null then
      raise exception 'Complete every customer reliability rating.' using errcode = '22023';
    end if;
    quality_value := null;
    punctuality_value := null;
    value_value := null;
    quote_accuracy_value := null;
  end if;

  if exists (
    select 1
    from unnest(array[
      quality_value,
      punctuality_value,
      value_value,
      quote_accuracy_value,
      description_accuracy_value,
      attendance_value,
      location_accessibility_value
    ]) as ratings(rating_value)
    where rating_value is not null and rating_value not between 1 and 5
  ) then
    raise exception 'Review ratings must be between 1 and 5.' using errcode = '22023';
  end if;

  insert into public.reviews (
    job_id,
    author_id,
    reviewed_user_id,
    direction,
    overall_rating,
    quality_rating,
    communication_rating,
    punctuality_rating,
    value_rating,
    quote_accuracy_rating,
    description_accuracy_rating,
    attendance_rating,
    location_accessibility_rating,
    comment
  ) values (
    target_job.id,
    caller_id,
    reviewed_id,
    review_direction,
    overall_value,
    quality_value,
    communication_value,
    punctuality_value,
    value_value,
    quote_accuracy_value,
    description_accuracy_value,
    attendance_value,
    location_accessibility_value,
    comment_value
  ) returning * into new_review;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    caller_id,
    'job.review_submitted',
    'review',
    new_review.id,
    jsonb_build_object('job_id', target_job.id, 'direction', review_direction)
  );

  return private.job_review_json(new_review);
end;
$$;

create or replace function public.respond_to_job_review(
  target_review_id uuid,
  response_text text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  normalized_response text := trim(response_text);
  target_review public.reviews%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if normalized_response is null
    or char_length(normalized_response) < 2
    or char_length(normalized_response) > 3000 then
    raise exception 'Enter a response between 2 and 3,000 characters.' using errcode = '22023';
  end if;

  select * into target_review
  from public.reviews as r
  where r.id = target_review_id and r.deleted_at is null
  for update;

  if not found then
    raise exception 'Review not found.' using errcode = 'P0002';
  end if;
  if target_review.direction <> 'customer_to_repairer'
    or target_review.reviewed_user_id <> caller_id then
    raise exception 'Only the reviewed repair professional can reply.' using errcode = '42501';
  end if;
  if target_review.repairer_response is not null then
    raise exception 'A response has already been submitted.' using errcode = '23514';
  end if;

  update public.reviews
  set repairer_response = normalized_response, responded_at = now()
  where id = target_review.id
  returning * into target_review;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    caller_id,
    'job.review_responded',
    'review',
    target_review.id,
    jsonb_build_object('job_id', target_review.job_id)
  );

  return private.job_review_json(target_review);
end;
$$;

revoke all on function private.job_review_json(public.reviews) from public, anon, authenticated;
revoke all on function private.job_json(public.jobs, uuid, boolean) from public, anon, authenticated;
revoke all on function public.get_jobs() from public, anon;
revoke all on function public.get_job_details(uuid) from public, anon;
revoke all on function public.submit_job_review(uuid, jsonb) from public, anon;
revoke all on function public.respond_to_job_review(uuid, text) from public, anon;

grant execute on function public.get_jobs() to authenticated;
grant execute on function public.get_job_details(uuid) to authenticated;
grant execute on function public.submit_job_review(uuid, jsonb) to authenticated;
grant execute on function public.respond_to_job_review(uuid, text) to authenticated;

-- Reviews are created and answered only through the validated RPC boundary.
revoke insert on public.reviews from authenticated;

-- The list and detail streams refresh when any relevant aggregate changes.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'jobs'
    ) then
      alter publication supabase_realtime add table public.jobs;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reviews'
    ) then
      alter publication supabase_realtime add table public.reviews;
    end if;
  end if;
end;
$$;

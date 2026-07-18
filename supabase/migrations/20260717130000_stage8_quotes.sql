-- FixBrief Stage 8: controlled provisional quote authoring, comparison,
-- expiration, withdrawal, and acceptance support.

create or replace function private.expire_stale_quotes()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  expired_count integer;
begin
  update public.quotes
  set status = 'expired', updated_at = now()
  where status = 'submitted'
    and expires_at <= now()
    and deleted_at is null;
  get diagnostics expired_count = row_count;
  return expired_count;
end;
$$;

revoke all on function private.expire_stale_quotes() from public, anon, authenticated;

create or replace function private.quote_payload_integer(
  payload jsonb,
  field_name text,
  fallback_value integer,
  minimum_value integer,
  maximum_value integer
)
returns integer
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  parsed_value integer;
begin
  if payload ->> field_name is null or btrim(payload ->> field_name) = '' then
    return fallback_value;
  end if;
  if payload ->> field_name !~ '^[0-9]+$' then
    raise exception '% must be a whole non-negative amount.', field_name
      using errcode = '22023';
  end if;
  parsed_value := (payload ->> field_name)::integer;
  if parsed_value < minimum_value or parsed_value > maximum_value then
    raise exception '% is outside the permitted range.', field_name
      using errcode = '22023';
  end if;
  return parsed_value;
end;
$$;

create or replace function private.quote_payload_text_array(
  payload jsonb,
  field_name text
)
returns text[]
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  result text[];
begin
  if payload -> field_name is null then
    return '{}';
  end if;
  if jsonb_typeof(payload -> field_name) <> 'array'
    or jsonb_array_length(payload -> field_name) > 12 then
    raise exception '% must contain no more than 12 entries.', field_name
      using errcode = '22023';
  end if;
  select coalesce(array_agg(btrim(value)), '{}') into result
  from jsonb_array_elements_text(payload -> field_name) as entry(value)
  where btrim(value) <> '';
  if exists (select 1 from unnest(result) as item where char_length(item) > 500) then
    raise exception '% entries must be 500 characters or fewer.', field_name
      using errcode = '22023';
  end if;
  return result;
end;
$$;

revoke all on function private.quote_payload_integer(jsonb, text, integer, integer, integer)
  from public, anon, authenticated;
revoke all on function private.quote_payload_text_array(jsonb, text)
  from public, anon, authenticated;

create or replace function private.quote_json(target_quote public.quotes)
returns jsonb
language sql
stable
set search_path = pg_catalog, public
as $$
  select to_jsonb(target_quote)
    || jsonb_build_object(
      'business_name', coalesce(rp.business_name, 'Repair professional'),
      'full_name', coalesce(rp.full_name, 'Repair professional'),
      'verification_status', rp.verification_status,
      'average_rating', rp.average_rating,
      'review_count', rp.review_count,
      'completed_job_count', rp.completed_job_count,
      'response_rate', rp.response_rate,
      'qualifications', rp.qualifications
    )
  from public.repairer_profiles as rp
  where rp.user_id = target_quote.repairer_id;
$$;

revoke all on function private.quote_json(public.quotes)
  from public, anon, authenticated;

create or replace function public.get_repairer_quote(target_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_quote public.quotes%rowtype;
begin
  if caller_id is null or private.current_user_role() <> 'repairer' then
    raise exception 'A repair professional account is required.' using errcode = '42501';
  end if;
  perform private.expire_stale_quotes();
  select * into selected_quote
  from public.quotes as q
  where q.request_id = target_request_id
    and q.repairer_id = caller_id
    and q.deleted_at is null
  order by q.created_at desc
  limit 1;
  if not found then
    return null;
  end if;
  return private.quote_json(selected_quote);
end;
$$;

create or replace function public.get_repairer_quotes()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null or private.current_user_role() <> 'repairer' then
    raise exception 'A repair professional account is required.' using errcode = '42501';
  end if;
  perform private.expire_stale_quotes();
  return coalesce((
    select jsonb_agg(
      private.quote_json(q)
        || jsonb_build_object(
          'item_name', r.item_name,
          'category_name', c.name,
          'approximate_area', r.approximate_area
        )
      order by q.updated_at desc
    )
    from public.quotes as q
    join public.repair_requests as r on r.id = q.request_id
    join public.repair_categories as c on c.id = r.category_id
    where q.repairer_id = caller_id and q.deleted_at is null
  ), '[]'::jsonb);
end;
$$;

create or replace function public.save_quote_draft(
  target_request_id uuid,
  target_quote_id uuid default null,
  quote_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_quote public.quotes%rowtype;
  saved_quote public.quotes%rowtype;
  inspection_fee integer;
  callout_fee integer;
  labour_minimum integer;
  labour_maximum integer;
  parts_minimum integer;
  parts_maximum integer;
  other_minimum integer;
  other_maximum integer;
  duration_minutes integer;
  warranty integer;
  earliest timestamptz;
  expiry timestamptz;
  comments text;
  assumptions_value text[];
  exclusions_value text[];
begin
  if caller_id is null or private.current_user_role() <> 'repairer' then
    raise exception 'A repair professional account is required.' using errcode = '42501';
  end if;
  if jsonb_typeof(coalesce(quote_payload, '{}'::jsonb)) <> 'object' then
    raise exception 'Quote details are invalid.' using errcode = '22023';
  end if;
  if not private.can_view_marketplace_request(target_request_id, caller_id) then
    raise exception 'This request is no longer available for quoting.' using errcode = '42501';
  end if;

  inspection_fee := private.quote_payload_integer(quote_payload, 'inspection_fee_minor', 0, 0, 100000000);
  callout_fee := private.quote_payload_integer(quote_payload, 'callout_fee_minor', 0, 0, 100000000);
  labour_minimum := private.quote_payload_integer(quote_payload, 'labour_minimum_minor', 0, 0, 100000000);
  labour_maximum := private.quote_payload_integer(quote_payload, 'labour_maximum_minor', 0, 0, 100000000);
  parts_minimum := private.quote_payload_integer(quote_payload, 'parts_minimum_minor', 0, 0, 100000000);
  parts_maximum := private.quote_payload_integer(quote_payload, 'parts_maximum_minor', 0, 0, 100000000);
  other_minimum := private.quote_payload_integer(quote_payload, 'other_charges_minimum_minor', 0, 0, 100000000);
  other_maximum := private.quote_payload_integer(quote_payload, 'other_charges_maximum_minor', 0, 0, 100000000);
  duration_minutes := private.quote_payload_integer(quote_payload, 'estimated_duration_minutes', 60, 1, 525600);
  warranty := private.quote_payload_integer(quote_payload, 'warranty_days', 0, 0, 3650);
  if labour_minimum > labour_maximum or parts_minimum > parts_maximum
    or other_minimum > other_maximum then
    raise exception 'Each minimum amount must be no greater than its maximum.' using errcode = '22023';
  end if;

  begin
    earliest := nullif(quote_payload ->> 'earliest_availability', '')::timestamptz;
    expiry := nullif(quote_payload ->> 'expires_at', '')::timestamptz;
  exception when invalid_datetime_format then
    raise exception 'Availability and expiry must be valid dates.' using errcode = '22023';
  end;
  comments := nullif(btrim(quote_payload ->> 'additional_comments'), '');
  if char_length(coalesce(comments, '')) > 5000 then
    raise exception 'Additional comments must be 5,000 characters or fewer.' using errcode = '22023';
  end if;
  assumptions_value := private.quote_payload_text_array(quote_payload, 'assumptions');
  exclusions_value := private.quote_payload_text_array(quote_payload, 'exclusions');

  if target_quote_id is null then
    if exists (
      select 1 from public.quotes as q
      where q.request_id = target_request_id and q.repairer_id = caller_id
        and q.deleted_at is null and q.status in ('draft', 'submitted', 'accepted')
    ) then
      raise exception 'An active quote already exists for this request.' using errcode = '23505';
    end if;
    insert into public.quotes (
      request_id, repairer_id, status, inspection_fee_minor, callout_fee_minor,
      labour_minimum_minor, labour_maximum_minor, parts_minimum_minor,
      parts_maximum_minor, other_charges_minimum_minor,
      other_charges_maximum_minor, earliest_availability,
      estimated_duration_minutes, collection_available,
      mobile_repair_available, warranty_days, expires_at,
      additional_comments, assumptions, exclusions
    ) values (
      target_request_id, caller_id, 'draft', inspection_fee, callout_fee,
      labour_minimum, labour_maximum, parts_minimum, parts_maximum,
      other_minimum, other_maximum, earliest, duration_minutes,
      coalesce((quote_payload ->> 'collection_available')::boolean, false),
      coalesce((quote_payload ->> 'mobile_repair_available')::boolean, false),
      warranty, expiry, comments, assumptions_value, exclusions_value
    ) returning * into saved_quote;
  else
    select * into selected_quote from public.quotes as q
    where q.id = target_quote_id for update;
    if not found or selected_quote.repairer_id <> caller_id
      or selected_quote.request_id <> target_request_id
      or selected_quote.deleted_at is not null then
      raise exception 'Quote not found.' using errcode = 'P0002';
    end if;
    if selected_quote.status not in ('draft', 'submitted') then
      raise exception 'This quote can no longer be edited.' using errcode = '23514';
    end if;
    if selected_quote.status = 'submitted' and (expiry is null or expiry <= now()) then
      raise exception 'A submitted quote needs a future expiry date.' using errcode = '23514';
    end if;
    update public.quotes
    set inspection_fee_minor = inspection_fee,
      callout_fee_minor = callout_fee,
      labour_minimum_minor = labour_minimum,
      labour_maximum_minor = labour_maximum,
      parts_minimum_minor = parts_minimum,
      parts_maximum_minor = parts_maximum,
      other_charges_minimum_minor = other_minimum,
      other_charges_maximum_minor = other_maximum,
      earliest_availability = earliest,
      estimated_duration_minutes = duration_minutes,
      collection_available = coalesce((quote_payload ->> 'collection_available')::boolean, false),
      mobile_repair_available = coalesce((quote_payload ->> 'mobile_repair_available')::boolean, false),
      warranty_days = warranty,
      expires_at = expiry,
      additional_comments = comments,
      assumptions = assumptions_value,
      exclusions = exclusions_value,
      updated_at = now()
    where id = selected_quote.id
    returning * into saved_quote;
  end if;
  return private.quote_json(saved_quote);
end;
$$;

create or replace function public.submit_quote(target_quote_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_quote public.quotes%rowtype;
begin
  if caller_id is null or private.current_user_role() <> 'repairer' then
    raise exception 'A repair professional account is required.' using errcode = '42501';
  end if;
  select * into selected_quote from public.quotes as q
  where q.id = target_quote_id for update;
  if not found or selected_quote.repairer_id <> caller_id
    or selected_quote.deleted_at is not null then
    raise exception 'Quote not found.' using errcode = 'P0002';
  end if;
  if selected_quote.status <> 'draft' then
    raise exception 'Only a draft quote can be submitted.' using errcode = '23514';
  end if;
  if selected_quote.total_maximum_minor <= 0 then
    raise exception 'Add an estimated cost before submitting.' using errcode = '23514';
  end if;
  if selected_quote.earliest_availability is null then
    raise exception 'Add your earliest availability before submitting.' using errcode = '23514';
  end if;
  if selected_quote.expires_at is null or selected_quote.expires_at <= now() then
    raise exception 'Choose a future quote expiry date.' using errcode = '23514';
  end if;
  update public.quotes set status = 'submitted', updated_at = now()
  where id = selected_quote.id returning * into selected_quote;
  update public.repair_requests
  set status = 'quotes_received', updated_at = now()
  where id = selected_quote.request_id and status in ('published', 'under_review');
  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (caller_id, 'quote.submitted', 'quote', selected_quote.id,
    jsonb_build_object('request_id', selected_quote.request_id));
  return private.quote_json(selected_quote);
end;
$$;

create or replace function public.withdraw_quote(target_quote_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_quote public.quotes%rowtype;
  previous_status public.quote_status;
begin
  if caller_id is null or private.current_user_role() <> 'repairer' then
    raise exception 'A repair professional account is required.' using errcode = '42501';
  end if;
  select * into selected_quote from public.quotes as q
  where q.id = target_quote_id for update;
  if not found or selected_quote.repairer_id <> caller_id
    or selected_quote.deleted_at is not null then
    raise exception 'Quote not found.' using errcode = 'P0002';
  end if;
  if selected_quote.status not in ('draft', 'submitted') then
    raise exception 'This quote can no longer be withdrawn.' using errcode = '23514';
  end if;
  previous_status := selected_quote.status;
  update public.quotes set status = 'withdrawn', updated_at = now()
  where id = selected_quote.id returning * into selected_quote;
  if previous_status = 'submitted' and not exists (
    select 1 from public.quotes as q where q.request_id = selected_quote.request_id
      and q.status = 'submitted' and q.deleted_at is null
  ) then
    update public.repair_requests set status = 'under_review', updated_at = now()
    where id = selected_quote.request_id and status = 'quotes_received';
  end if;
  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (caller_id, 'quote.withdrawn', 'quote', selected_quote.id,
    jsonb_build_object('request_id', selected_quote.request_id));
  return private.quote_json(selected_quote);
end;
$$;

create or replace function public.get_customer_quote_comparison(target_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  caller_id uuid := (select auth.uid());
  selected_request public.repair_requests%rowtype;
  result jsonb;
begin
  if caller_id is null or private.current_user_role() <> 'customer' then
    raise exception 'A customer account is required.' using errcode = '42501';
  end if;
  select * into selected_request from public.repair_requests as r
  where r.id = target_request_id and r.deleted_at is null;
  if not found or selected_request.customer_id <> caller_id then
    raise exception 'Repair request not found.' using errcode = 'P0002';
  end if;
  perform private.expire_stale_quotes();

  with quote_metrics as (
    select
      q.*,
      rp.business_name,
      rp.full_name,
      rp.average_rating,
      rp.review_count,
      rp.completed_job_count,
      rp.response_rate,
      rp.qualifications,
      rp.verification_status,
      case when rp.business_location is not null and location.location is not null
        then round((st_distance(rp.business_location, location.location) / 1000)::numeric, 1)
        else null end as distance_kilometres,
      coalesce((select round(avg(rv.quote_accuracy_rating)::numeric, 1)
        from public.reviews as rv
        where rv.reviewed_user_id = rp.user_id and rv.deleted_at is null
          and rv.quote_accuracy_rating is not null), 0) as quote_accuracy_rating,
      (
        rp.average_rating * 5
        + least(rp.completed_job_count, 300) / 30.0
        + case when rp.verification_status = 'verified' then 10 else 0 end
        + least(q.warranty_days, 180) / 12.0
        + case when q.earliest_availability <= now() + interval '2 days' then 15 else 4 end
        + rp.response_rate / 10.0
        + case when cardinality(rp.qualifications) > 0 then 10 else 0 end
      )::numeric as fit_score
    from public.quotes as q
    join public.repairer_profiles as rp on rp.user_id = q.repairer_id
    left join public.repair_request_private_locations as location
      on location.request_id = q.request_id
    where q.request_id = target_request_id
      and q.deleted_at is null
      and q.status in ('submitted', 'accepted', 'rejected', 'expired')
  ), ranked as (
    select quote_metrics.*,
      rank() over (
        order by case when status = 'submitted' then 0 else 1 end,
          fit_score desc, submitted_at asc
      ) as fit_rank
    from quote_metrics
  )
  select jsonb_build_object(
    'request_id', selected_request.id,
    'item_name', selected_request.item_name,
    'request_status', selected_request.status,
    'accepted_quote_id', (
      select q.id from public.quotes as q
      where q.request_id = selected_request.id and q.status = 'accepted'
      limit 1
    ),
    'job_id', (
      select j.id from public.jobs as j
      where j.request_id = selected_request.id and j.deleted_at is null
      limit 1
    ),
    'quotes', coalesce((
      select jsonb_agg(
        (to_jsonb(ranked) - 'fit_score' - 'fit_rank')
          || jsonb_build_object(
            'business_name', ranked.business_name,
            'full_name', ranked.full_name,
            'average_rating', ranked.average_rating,
            'review_count', ranked.review_count,
            'completed_job_count', ranked.completed_job_count,
            'response_rate', ranked.response_rate,
            'qualifications', ranked.qualifications,
            'verification_status', ranked.verification_status,
            'distance_kilometres', ranked.distance_kilometres,
            'quote_accuracy_rating', ranked.quote_accuracy_rating,
            'is_recommended', ranked.fit_rank = 1 and ranked.status = 'submitted',
            'recommendation_label', case
              when ranked.fit_rank = 1 and ranked.status = 'submitted' then 'Strong overall fit'
              else null end,
            'recommendation_reasons', to_jsonb(array_remove(array[
              case when ranked.average_rating >= 4.5 then 'Strong customer rating' end,
              case when ranked.earliest_availability <= now() + interval '2 days' then 'Fast availability' end,
              case when cardinality(ranked.qualifications) > 0 then 'Relevant qualifications listed' end,
              case when ranked.warranty_days >= 90 then 'Meaningful warranty included' end,
              case when ranked.quote_accuracy_rating >= 4 then 'Strong quote accuracy history' end,
              case when ranked.verification_status = 'verified' then 'Identity and business verified' end
            ], null))
          )
        order by case ranked.status when 'accepted' then 0 when 'submitted' then 1 else 2 end,
          ranked.fit_score desc
      ) from ranked
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- Customers must never see a repairer's draft or withdrawn quote through the
-- base tables. They receive only submitted lifecycle states or the safe RPC.
drop policy if exists quotes_read_parties on public.quotes;
create policy quotes_read_parties
  on public.quotes for select to authenticated
  using (
    deleted_at is null and (
      repairer_id = (select auth.uid())
      or (
        status in ('submitted', 'accepted', 'rejected', 'expired')
        and exists (
          select 1 from public.repair_requests as r
          where r.id = request_id and r.customer_id = (select auth.uid())
        )
      )
    )
  );

drop policy if exists quote_items_read_parties on public.quote_items;
create policy quote_items_read_parties on public.quote_items for select to authenticated
  using (deleted_at is null and exists (
    select 1 from public.quotes as q
    join public.repair_requests as r on r.id = q.request_id
    where q.id = quote_id and q.deleted_at is null
      and (
        q.repairer_id = (select auth.uid())
        or (r.customer_id = (select auth.uid())
          and q.status in ('submitted', 'accepted', 'rejected', 'expired'))
      )
  ));

revoke all on function public.get_repairer_quote(uuid) from public, anon;
revoke all on function public.get_repairer_quotes() from public, anon;
revoke all on function public.save_quote_draft(uuid, uuid, jsonb) from public, anon;
revoke all on function public.submit_quote(uuid) from public, anon;
revoke all on function public.withdraw_quote(uuid) from public, anon;
revoke all on function public.get_customer_quote_comparison(uuid) from public, anon;

grant execute on function public.get_repairer_quote(uuid) to authenticated;
grant execute on function public.get_repairer_quotes() to authenticated;
grant execute on function public.save_quote_draft(uuid, uuid, jsonb) to authenticated;
grant execute on function public.submit_quote(uuid) to authenticated;
grant execute on function public.withdraw_quote(uuid) to authenticated;
grant execute on function public.get_customer_quote_comparison(uuid) to authenticated;

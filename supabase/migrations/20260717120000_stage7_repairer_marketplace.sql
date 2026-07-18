-- FixBrief Stage 7: ranked repairer marketplace, privacy-safe request detail,
-- repairer public profiles, and dashboard summaries.

create or replace function private.marketplace_safe_text(input_text text)
returns text
language sql
immutable
strict
set search_path = pg_catalog
as $$
  select btrim(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          input_text,
          '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}',
          '[email removed]',
          'gi'
        ),
        '(\+?44[[:space:].()-]*|0)[0-9][0-9[:space:].()-]{7,}[0-9]',
        '[phone removed]',
        'gi'
      ),
      '\m[0-9]{1,5}[[:space:]]+[[:alnum:] .''-]{2,50}[[:space:]]+(street|road|avenue|lane|drive|close|way|court|terrace|place)\M',
      '[address removed]',
      'gi'
    )
  )
$$;

comment on function private.marketplace_safe_text(text) is
  'Defence-in-depth redaction for free text shown in the pre-quote marketplace.';

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
      and (r.urgency <> 'emergency' or rp.emergency_service_available)
      and (not r.collection_required or rp.collection_service_available)
      and (not r.mobile_repair_required or rp.mobile_repair_available)
      and not exists (
        select 1
        from public.availability_slots as unavailable
        where unavailable.repairer_id = viewer_id
          and unavailable.kind = 'unavailable'
          and unavailable.is_active
          and unavailable.deleted_at is null
          and coalesce(r.preferred_repair_date, current_date)
            between unavailable.valid_from and coalesce(unavailable.valid_until, unavailable.valid_from)
      )
      and exists (
        select 1
        from public.repairer_specialisations as rs
        where rs.repairer_id = viewer_id
          and rs.category_id = r.category_id
          and (
            r.subcategory_id is null
            or rs.subcategory_id is null
            or rs.subcategory_id = r.subcategory_id
          )
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

create or replace function public.get_ranked_marketplace_requests(
  category_filter uuid default null,
  urgency_filter public.urgency_level default null,
  maximum_distance_kilometres numeric default null,
  search_query text default null,
  mobile_only boolean default false,
  collection_only boolean default false,
  sort_mode text default 'best_match',
  result_limit integer default 50,
  result_offset integer default 0
)
returns table (
  id uuid,
  category_id uuid,
  category_name text,
  subcategory_id uuid,
  subcategory_name text,
  item_name text,
  problem_summary text,
  urgency public.urgency_level,
  approximate_area text,
  distance_kilometres numeric,
  mobile_repair_required boolean,
  collection_required boolean,
  inspection_required boolean,
  evidence_count bigint,
  safety_risk public.risk_level,
  stop_using_item boolean,
  match_score numeric,
  match_reasons text[],
  published_at timestamptz,
  total_count bigint
)
language sql
stable
security definer
set search_path = pg_catalog, public, private, extensions
as $$
  with repairer as (
    select rp.*
    from public.repairer_profiles as rp
    join public.profiles as p on p.id = rp.user_id
    where rp.user_id = (select auth.uid())
      and p.role = 'repairer'
      and p.account_status = 'active'
      and p.deleted_at is null
      and rp.deleted_at is null
  ),
  eligible as (
    select
      r.*,
      category.name as category_name,
      subcategory.name as subcategory_name,
      repairer.average_rating,
      repairer.response_rate,
      repairer.service_radius_kilometres,
      repairer.emergency_service_available,
      distance.distance_kilometres,
      coalesce(assessment.problem_summary, r.problem_description, r.item_name, 'Repair request') as raw_summary,
      coalesce(assessment.safety_risk, 'none'::public.risk_level) as safety_risk,
      coalesce(assessment.stop_using_item, false) as stop_using_item,
      exists (
        select 1
        from public.repairer_specialisations as exact_specialisation
        where exact_specialisation.repairer_id = repairer.user_id
          and exact_specialisation.category_id = r.category_id
          and exact_specialisation.subcategory_id = r.subcategory_id
          and exact_specialisation.deleted_at is null
      ) as exact_specialisation,
      (
        not exists (
          select 1 from public.availability_slots as any_slot
          where any_slot.repairer_id = repairer.user_id
            and any_slot.is_active
            and any_slot.deleted_at is null
        )
        or exists (
          select 1
          from public.availability_slots as available
          where available.repairer_id = repairer.user_id
            and available.kind in ('recurring', 'exception')
            and available.is_active
            and available.deleted_at is null
            and (
              (
                available.kind = 'recurring'
                and available.weekday = extract(
                  isodow from coalesce(r.preferred_repair_date, current_date)
                )::smallint
              )
              or (
                available.kind = 'exception'
                and coalesce(r.preferred_repair_date, current_date)
                  between available.valid_from and coalesce(available.valid_until, available.valid_from)
              )
            )
        )
      ) as availability_match,
      (
        select count(*)
        from public.repair_request_media as media
        where media.request_id = r.id
          and media.upload_status = 'ready'
          and media.deleted_at is null
      ) as evidence_count
    from public.repair_requests as r
    cross join repairer
    join public.repair_categories as category on category.id = r.category_id
    left join public.repair_subcategories as subcategory on subcategory.id = r.subcategory_id
    left join lateral (
      select a.problem_summary, a.safety_risk, a.stop_using_item
      from public.ai_assessments as a
      where a.request_id = r.id and a.validation_status = 'valid'
      order by a.version desc
      limit 1
    ) as assessment on true
    left join lateral (
      select round(min(candidate.kilometres)::numeric, 2) as distance_kilometres
      from (
        select extensions.st_distance(
          repairer.business_location,
          r.approximate_location
        ) / 1000 as kilometres
        where repairer.business_location is not null
          and r.approximate_location is not null
        union all
        select extensions.st_distance(
          service_area.centre,
          r.approximate_location
        ) / 1000 as kilometres
        from public.service_areas as service_area
        where service_area.repairer_id = repairer.user_id
          and service_area.centre is not null
          and r.approximate_location is not null
          and service_area.is_active
          and service_area.deleted_at is null
      ) as candidate
    ) as distance on true
    where private.can_view_marketplace_request(r.id, repairer.user_id)
      and (category_filter is null or r.category_id = category_filter)
      and (urgency_filter is null or r.urgency = urgency_filter)
      and (
        maximum_distance_kilometres is null
        or distance.distance_kilometres <= maximum_distance_kilometres
      )
      and (not mobile_only or r.mobile_repair_required)
      and (not collection_only or r.collection_required)
      and (
        nullif(btrim(search_query), '') is null
        or private.marketplace_safe_text(coalesce(r.item_name, '')) ilike '%' || btrim(search_query) || '%'
        or private.marketplace_safe_text(coalesce(r.problem_description, '')) ilike '%' || btrim(search_query) || '%'
        or category.name ilike '%' || btrim(search_query) || '%'
        or coalesce(subcategory.name, '') ilike '%' || btrim(search_query) || '%'
        or coalesce(r.approximate_area, '') ilike '%' || btrim(search_query) || '%'
      )
  ),
  scored as (
    select
      eligible.*,
      least(
        100,
        (case when exact_specialisation then 25 else 18 end)
        + case
            when distance_kilometres is null then 12
            else greatest(0, 25 - (distance_kilometres / greatest(service_radius_kilometres, 1) * 12))
          end
        + case when availability_match then 10 else 2 end
        + (least(average_rating, 5) / 5 * 15)
        + (least(response_rate, 100) / 100 * 10)
        + case
            when urgency in ('emergency', 'asap', 'within_24_hours') and emergency_service_available then 10
            when urgency in ('within_3_days', 'within_1_week') then 7
            else 5
          end
        + case when mobile_repair_required or collection_required then 5 else 3 end
      )::numeric(5, 2) as match_score,
      array_remove(array[
        case when exact_specialisation then 'Exact subcategory specialisation' else 'Matching repair category' end,
        case when distance_kilometres is not null then round(distance_kilometres, 1)::text || ' km within your service area' end,
        case when availability_match then 'Availability matches the preferred timing' end,
        case when mobile_repair_required then 'Mobile service requested and available' end,
        case when collection_required then 'Collection requested and available' end,
        case when average_rating >= 4.5 then 'Strong customer rating' end,
        case when response_rate >= 90 then 'Strong response history' end,
        case when urgency in ('emergency', 'asap', 'within_24_hours') and emergency_service_available then 'High-urgency availability' end
      ], null)::text[] as match_reasons,
      case urgency
        when 'emergency' then 1
        when 'asap' then 2
        when 'within_24_hours' then 3
        when 'within_3_days' then 4
        when 'within_1_week' then 5
        else 6
      end as urgency_rank
    from eligible
  )
  select
    scored.id,
    scored.category_id,
    scored.category_name,
    scored.subcategory_id,
    scored.subcategory_name,
    private.marketplace_safe_text(coalesce(scored.item_name, 'Repair request')) as item_name,
    private.marketplace_safe_text(scored.raw_summary) as problem_summary,
    scored.urgency,
    coalesce(scored.approximate_area, 'Approximate area withheld') as approximate_area,
    scored.distance_kilometres,
    scored.mobile_repair_required,
    scored.collection_required,
    scored.inspection_required,
    scored.evidence_count,
    scored.safety_risk,
    scored.stop_using_item,
    scored.match_score,
    scored.match_reasons,
    scored.published_at,
    count(*) over () as total_count
  from scored
  order by
    case when sort_mode = 'nearest' then scored.distance_kilometres end asc nulls last,
    case when sort_mode = 'newest' then scored.published_at end desc,
    case when sort_mode = 'urgent' then scored.urgency_rank end asc,
    case when sort_mode not in ('nearest', 'newest', 'urgent') then scored.match_score end desc,
    scored.match_score desc,
    scored.published_at desc
  limit least(greatest(coalesce(result_limit, 50), 1), 100)
  offset least(greatest(coalesce(result_offset, 0), 0), 1000)
$$;

create or replace function public.get_marketplace_request_detail(
  target_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  category_filter_id uuid;
  ranked_request jsonb;
  request_payload jsonb;
  symptoms_payload jsonb;
  evidence_payload jsonb;
  assessment_payload jsonb;
begin
  if (select auth.uid()) is null
    or not private.can_view_marketplace_request(target_request_id, (select auth.uid())) then
    raise exception 'This repair request is not available to this repairer.' using errcode = '42501';
  end if;

  select r.category_id into category_filter_id
  from public.repair_requests as r
  where r.id = target_request_id and r.deleted_at is null;

  select to_jsonb(match)
  into ranked_request
  from public.get_ranked_marketplace_requests(
    category_filter_id,
    null,
    null,
    null,
    false,
    false,
    'best_match',
    100,
    0
  ) as match
  where match.id = target_request_id;

  select
    coalesce(ranked_request, jsonb_build_object(
      'id', r.id,
      'category_id', r.category_id,
      'category_name', category.name,
      'subcategory_id', r.subcategory_id,
      'subcategory_name', subcategory.name,
      'item_name', private.marketplace_safe_text(coalesce(r.item_name, 'Repair request')),
      'problem_summary', private.marketplace_safe_text(coalesce(r.problem_description, 'Repair request')),
      'urgency', r.urgency,
      'approximate_area', coalesce(r.approximate_area, 'Approximate area withheld'),
      'match_score', 0,
      'match_reasons', array['Matching verified service'],
      'published_at', r.published_at
    )) || jsonb_build_object(
      'brand', r.brand,
      'model', r.model,
      'previous_repairs', private.marketplace_safe_text(coalesce(r.previous_repairs, '')),
      'problem_description', private.marketplace_safe_text(coalesce(r.problem_description, '')),
      'structured_brief', private.marketplace_safe_text(coalesce(r.structured_brief, '')),
      'preferred_repair_date', r.preferred_repair_date
    )
  into request_payload
  from public.repair_requests as r
  join public.repair_categories as category on category.id = r.category_id
  left join public.repair_subcategories as subcategory on subcategory.id = r.subcategory_id
  where r.id = target_request_id;

  select coalesce(
    jsonb_agg(private.marketplace_safe_text(symptom.description) order by symptom.sort_order),
    '[]'::jsonb
  )
  into symptoms_payload
  from public.repair_request_symptoms as symptom
  where symptom.request_id = target_request_id
    and symptom.deleted_at is null;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', media.id,
        'kind', media.kind,
        'bucket_name', media.bucket_name,
        'object_path', media.object_path,
        'mime_type', media.mime_type,
        'duration_milliseconds', media.duration_milliseconds,
        'label', case media.kind
          when 'image' then 'Customer photo'
          when 'video' then 'Customer video'
          when 'audio' then 'Customer audio'
          when 'error_code' then 'Error-code evidence'
          when 'receipt' then 'Purchase receipt'
          when 'warranty' then 'Warranty evidence'
          else 'Customer document'
        end
      ) order by media.sort_order
    ),
    '[]'::jsonb
  )
  into evidence_payload
  from public.repair_request_media as media
  where media.request_id = target_request_id
    and media.upload_status = 'ready'
    and media.deleted_at is null;

  select jsonb_build_object(
    'problem_summary', private.marketplace_safe_text(assessment.problem_summary),
    'disclaimer', assessment.disclaimer,
    'confidence', assessment.confidence,
    'safety_risk', assessment.safety_risk,
    'stop_using_item', assessment.stop_using_item,
    'safety_warning', assessment.safety_warning,
    'recommended_professional_type', assessment.recommended_professional_type,
    'inspection_recommendation', assessment.inspection_recommendation,
    'possible_causes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'cause', cause.cause,
        'confidence', cause.confidence,
        'reasoning_summary', cause.reasoning_summary
      ) order by cause.sort_order)
      from public.ai_possible_causes as cause
      where cause.assessment_id = assessment.id
        and not cause.hidden_from_customer
    ), '[]'::jsonb)
  )
  into assessment_payload
  from public.ai_assessments as assessment
  where assessment.request_id = target_request_id
    and assessment.validation_status = 'valid'
  order by assessment.version desc
  limit 1;

  return jsonb_build_object(
    'request', request_payload,
    'symptoms', symptoms_payload,
    'evidence', evidence_payload,
    'assessment', assessment_payload,
    'privacy_notice',
      'Only the customer''s approximate area is visible. Their name, contact details and exact address remain private until a quote is accepted or an inspection is confirmed.'
  );
end;
$$;

create or replace function public.get_repairer_marketplace_profile(
  target_repairer_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  resolved_repairer_id uuid := coalesce(target_repairer_id, (select auth.uid()));
  result jsonb;
begin
  if resolved_repairer_id is null then
    raise exception 'A repairer profile is required.' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'user_id', profile.user_id,
    'full_name', profile.full_name,
    'business_name', profile.business_name,
    'logo_path', profile.logo_path,
    'business_description', profile.business_description,
    'years_experience', profile.years_experience,
    'qualifications', profile.qualifications,
    'inspection_fee_minor', profile.inspection_fee_minor,
    'currency_code', profile.currency_code,
    'service_radius_kilometres', profile.service_radius_kilometres,
    'working_hours', profile.working_hours,
    'emergency_service_available', profile.emergency_service_available,
    'mobile_repair_available', profile.mobile_repair_available,
    'collection_service_available', profile.collection_service_available,
    'verification_status', profile.verification_status,
    'average_rating', profile.average_rating,
    'review_count', profile.review_count,
    'completed_job_count', profile.completed_job_count,
    'response_rate', profile.response_rate,
    'quote_acceptance_rate', profile.quote_acceptance_rate,
    'specialisations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'category', category.name,
        'subcategory', subcategory.name,
        'specialisation', specialisation.specialisation,
        'years_experience', specialisation.years_experience
      ) order by category.sort_order, subcategory.sort_order nulls first, specialisation.specialisation)
      from public.repairer_specialisations as specialisation
      join public.repair_categories as category on category.id = specialisation.category_id
      left join public.repair_subcategories as subcategory on subcategory.id = specialisation.subcategory_id
      where specialisation.repairer_id = profile.user_id
        and specialisation.deleted_at is null
    ), '[]'::jsonb),
    'certifications', coalesce((
      select jsonb_agg(certification.name order by certification.name)
      from public.repairer_certifications as certification
      where certification.repairer_id = profile.user_id
        and certification.verification_status = 'verified'
        and certification.deleted_at is null
    ), '[]'::jsonb),
    'service_areas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'area_name', area.area_name,
        'radius_kilometres', area.radius_kilometres,
        'emergency_service', area.emergency_service,
        'mobile_repair', area.mobile_repair,
        'collection_service', area.collection_service
      ) order by area.area_name)
      from public.service_areas as area
      where area.repairer_id = profile.user_id
        and area.is_active
        and area.deleted_at is null
    ), '[]'::jsonb),
    'availability', coalesce((
      select jsonb_agg(
        case slot.kind
          when 'recurring' then
            (array['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])[slot.weekday]
            || ' · ' || to_char(slot.starts_at, 'HH24:MI')
            || '–' || to_char(slot.ends_at, 'HH24:MI')
          when 'exception' then 'Available · ' || to_char(slot.valid_from, 'DD Mon YYYY')
          else 'Unavailable · ' || to_char(slot.valid_from, 'DD Mon YYYY')
        end
        order by slot.kind, slot.weekday nulls last, slot.valid_from nulls last
      )
      from public.availability_slots as slot
      where slot.repairer_id = profile.user_id
        and slot.is_active
        and slot.deleted_at is null
        and slot.kind <> 'unavailable'
    ), '[]'::jsonb)
  )
  into result
  from public.repairer_profiles as profile
  where profile.user_id = resolved_repairer_id
    and profile.deleted_at is null
    and (
      profile.user_id = (select auth.uid())
      or (
        profile.is_marketplace_visible
        and profile.verification_status = 'verified'
      )
    );

  if result is null then
    raise exception 'Repairer profile not found.' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function public.get_repairer_marketplace_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  viewer_id uuid := (select auth.uid());
  new_matches integer := 0;
  nearby_matches integer := 0;
  urgent_matches integer := 0;
begin
  if viewer_id is null or not exists (
    select 1
    from public.profiles as profile
    where profile.id = viewer_id
      and profile.role = 'repairer'
      and profile.account_status = 'active'
      and profile.deleted_at is null
  ) then
    raise exception 'A repairer account is required.' using errcode = '42501';
  end if;

  select
    count(*)::integer,
    count(*) filter (where match.distance_kilometres <= 8)::integer,
    count(*) filter (where match.urgency in ('emergency', 'asap', 'within_24_hours'))::integer
  into new_matches, nearby_matches, urgent_matches
  from public.get_ranked_marketplace_requests(
    null, null, null, null, false, false, 'best_match', 100, 0
  ) as match;

  return jsonb_build_object(
    'new_match_count', new_matches,
    'nearby_count', nearby_matches,
    'high_urgency_count', urgent_matches,
    'submitted_quote_count', (
      select count(*) from public.quotes as quote
      where quote.repairer_id = viewer_id
        and quote.status = 'submitted'
        and quote.deleted_at is null
    ),
    'active_job_count', (
      select count(*) from public.jobs as job
      where job.repairer_id = viewer_id
        and job.status not in ('completed', 'cancelled')
        and job.deleted_at is null
    ),
    'ongoing_job_count', (
      select count(*) from public.jobs as job
      where job.repairer_id = viewer_id
        and job.status = 'repair_in_progress'
        and job.deleted_at is null
    ),
    'waiting_for_parts_count', (
      select count(*) from public.jobs as job
      where job.repairer_id = viewer_id
        and job.status = 'waiting_for_parts'
        and job.deleted_at is null
    ),
    'completed_job_count', (
      select count(*) from public.jobs as job
      where job.repairer_id = viewer_id
        and job.status = 'completed'
        and job.deleted_at is null
    ),
    'today_appointment_count', (
      select count(*)
      from public.appointments as appointment
      join public.jobs as job on job.id = appointment.job_id
      where job.repairer_id = viewer_id
        and appointment.status = 'confirmed'
        and appointment.starts_at >= current_date
        and appointment.starts_at < current_date + interval '1 day'
        and appointment.deleted_at is null
        and job.deleted_at is null
    ),
    'month_earnings_minor', coalesce((
      select sum((job.agreed_minimum_minor + job.agreed_maximum_minor) / 2)
      from public.jobs as job
      where job.repairer_id = viewer_id
        and job.status = 'completed'
        and job.completed_at >= date_trunc('month', now())
        and job.deleted_at is null
    ), 0)
  );
end;
$$;

revoke all on function private.marketplace_safe_text(text) from public, anon, authenticated;
revoke all on function public.get_ranked_marketplace_requests(
  uuid, public.urgency_level, numeric, text, boolean, boolean, text, integer, integer
) from public, anon;
revoke all on function public.get_marketplace_request_detail(uuid) from public, anon;
revoke all on function public.get_repairer_marketplace_profile(uuid) from public, anon;
revoke all on function public.get_repairer_marketplace_summary() from public, anon;

grant execute on function public.get_ranked_marketplace_requests(
  uuid, public.urgency_level, numeric, text, boolean, boolean, text, integer, integer
) to authenticated;
grant execute on function public.get_marketplace_request_detail(uuid) to authenticated;
grant execute on function public.get_repairer_marketplace_profile(uuid) to authenticated;
grant execute on function public.get_repairer_marketplace_summary() to authenticated;

comment on function public.get_ranked_marketplace_requests(
  uuid, public.urgency_level, numeric, text, boolean, boolean, text, integer, integer
) is 'Returns only eligible, privacy-safe repair requests with explainable match scores.';
comment on function public.get_marketplace_request_detail(uuid) is
  'Returns the approved brief and eligible evidence without customer identity or precise location.';
comment on function public.get_repairer_marketplace_profile(uuid) is
  'Returns a public-safe repairer profile without private contact or precise business location data.';

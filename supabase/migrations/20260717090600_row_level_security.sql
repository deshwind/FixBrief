-- FixBrief Stage 4: explicit grants and row-level security for every public
-- table. No public table relies on the Data API's legacy automatic grants.

grant usage on schema public to anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

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
    'idempotency_keys',
    'audit_events',
    'repair_requests',
    'repair_request_private_locations',
    'repair_request_symptoms',
    'repair_request_media',
    'ai_assessments',
    'ai_possible_causes',
    'ai_follow_up_questions',
    'quotes',
    'quote_items',
    'jobs',
    'job_status_history',
    'appointments',
    'conversations',
    'conversation_participants',
    'messages',
    'reviews',
    'notifications',
    'saved_repairers',
    'reports',
    'blocked_users',
    'ai_usage_events'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end;
$$;

-- Public catalogue data.
grant select on public.repair_categories, public.repair_subcategories to anon, authenticated;

create policy repair_categories_public_read
  on public.repair_categories for select
  to anon, authenticated
  using (is_active and deleted_at is null);

create policy repair_subcategories_public_read
  on public.repair_subcategories for select
  to anon, authenticated
  using (
    is_active
    and deleted_at is null
    and exists (
      select 1 from public.repair_categories as c
      where c.id = category_id and c.is_active and c.deleted_at is null
    )
  );

-- Base identity and role-specific profiles.
grant select on public.profiles to authenticated;
grant update (display_name, avatar_path, last_seen_at, updated_at, updated_by)
  on public.profiles to authenticated;

create policy profiles_read_own
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()) and deleted_at is null);

create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()) and deleted_at is null and account_status = 'active')
  with check (id = (select auth.uid()) and deleted_at is null and account_status = 'active');

grant select on public.customer_profiles to authenticated;
grant update (
  full_name,
  phone_number,
  location_label,
  approximate_location,
  preferred_contact,
  push_notifications,
  email_notifications,
  updated_at
) on public.customer_profiles to authenticated;

create policy customer_profiles_read_own
  on public.customer_profiles for select
  to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null);

create policy customer_profiles_update_own
  on public.customer_profiles for update
  to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null)
  with check (user_id = (select auth.uid()) and deleted_at is null);

grant select (
  user_id,
  full_name,
  business_name,
  logo_path,
  business_description,
  years_experience,
  qualifications,
  inspection_fee_minor,
  currency_code,
  service_radius_kilometres,
  working_hours,
  emergency_service_available,
  mobile_repair_available,
  collection_service_available,
  verification_status,
  verified_at,
  is_marketplace_visible,
  average_rating,
  review_count,
  completed_job_count,
  response_rate,
  quote_acceptance_rate,
  created_at,
  updated_at
) on public.repairer_profiles to authenticated;
grant update (
  full_name,
  business_name,
  logo_path,
  phone_number,
  business_email,
  business_description,
  years_experience,
  qualifications,
  inspection_fee_minor,
  currency_code,
  service_radius_kilometres,
  business_address,
  business_location,
  working_hours,
  emergency_service_available,
  mobile_repair_available,
  collection_service_available,
  updated_at
) on public.repairer_profiles to authenticated;

create policy repairer_profiles_read_own_or_marketplace
  on public.repairer_profiles for select
  to authenticated
  using (
    deleted_at is null
    and (
      user_id = (select auth.uid())
      or (is_marketplace_visible and verification_status = 'verified')
    )
  );

create policy repairer_profiles_update_own
  on public.repairer_profiles for update
  to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null)
  with check (user_id = (select auth.uid()) and deleted_at is null);

-- Repairer catalogue joins and private certification evidence.
grant select, insert, delete on public.repairer_specialisations to authenticated;
grant update (subcategory_id, specialisation, years_experience, updated_at)
  on public.repairer_specialisations to authenticated;

create policy repairer_specialisations_read
  on public.repairer_specialisations for select
  to authenticated
  using (
    deleted_at is null
    and (
      repairer_id = (select auth.uid())
      or exists (
        select 1 from public.repairer_profiles as rp
        where rp.user_id = repairer_id
          and rp.is_marketplace_visible
          and rp.verification_status = 'verified'
          and rp.deleted_at is null
      )
    )
  );

create policy repairer_specialisations_insert_own
  on public.repairer_specialisations for insert
  to authenticated
  with check (repairer_id = (select auth.uid()) and deleted_at is null);

create policy repairer_specialisations_update_own
  on public.repairer_specialisations for update
  to authenticated
  using (repairer_id = (select auth.uid()) and deleted_at is null)
  with check (repairer_id = (select auth.uid()) and deleted_at is null);

create policy repairer_specialisations_delete_own
  on public.repairer_specialisations for delete
  to authenticated
  using (repairer_id = (select auth.uid()));

grant select, insert, delete on public.repairer_certifications to authenticated;
grant update (
  name,
  issuer,
  qualification_number,
  issued_on,
  expires_on,
  object_path,
  updated_at,
  deleted_at
) on public.repairer_certifications to authenticated;

create policy repairer_certifications_read_own
  on public.repairer_certifications for select
  to authenticated
  using (repairer_id = (select auth.uid()) and deleted_at is null);

create policy repairer_certifications_insert_own
  on public.repairer_certifications for insert
  to authenticated
  with check (
    repairer_id = (select auth.uid())
    and verification_status = 'unverified'
    and verified_at is null
    and verified_by is null
    and deleted_at is null
  );

create policy repairer_certifications_update_own
  on public.repairer_certifications for update
  to authenticated
  using (repairer_id = (select auth.uid()) and deleted_at is null)
  with check (repairer_id = (select auth.uid()));

create policy repairer_certifications_delete_own
  on public.repairer_certifications for delete
  to authenticated
  using (repairer_id = (select auth.uid()));

grant select, insert, update, delete on public.service_areas, public.availability_slots to authenticated;

create policy service_areas_read
  on public.service_areas for select
  to authenticated
  using (
    deleted_at is null
    and (
      repairer_id = (select auth.uid())
      or exists (
        select 1 from public.repairer_profiles as rp
        where rp.user_id = repairer_id
          and rp.is_marketplace_visible
          and rp.verification_status = 'verified'
          and rp.deleted_at is null
      )
    )
  );
create policy service_areas_insert_own on public.service_areas for insert to authenticated
  with check (repairer_id = (select auth.uid()) and deleted_at is null);
create policy service_areas_update_own on public.service_areas for update to authenticated
  using (repairer_id = (select auth.uid()) and deleted_at is null)
  with check (repairer_id = (select auth.uid()));
create policy service_areas_delete_own on public.service_areas for delete to authenticated
  using (repairer_id = (select auth.uid()));

create policy availability_slots_read
  on public.availability_slots for select
  to authenticated
  using (
    deleted_at is null
    and (
      repairer_id = (select auth.uid())
      or exists (
        select 1 from public.repairer_profiles as rp
        where rp.user_id = repairer_id
          and rp.is_marketplace_visible
          and rp.verification_status = 'verified'
          and rp.deleted_at is null
      )
    )
  );
create policy availability_slots_insert_own on public.availability_slots for insert to authenticated
  with check (repairer_id = (select auth.uid()) and deleted_at is null);
create policy availability_slots_update_own on public.availability_slots for update to authenticated
  using (repairer_id = (select auth.uid()) and deleted_at is null)
  with check (repairer_id = (select auth.uid()));
create policy availability_slots_delete_own on public.availability_slots for delete to authenticated
  using (repairer_id = (select auth.uid()));

grant select on public.idempotency_keys to authenticated;
create policy idempotency_keys_read_own
  on public.idempotency_keys for select
  to authenticated
  using (user_id = (select auth.uid()) and expires_at > now());

-- Repair requests keep precise locations in a separate table.
grant select, insert, delete on public.repair_requests to authenticated;
grant update (
  category_id,
  subcategory_id,
  item_name,
  brand,
  model,
  approximate_age_years,
  serial_number,
  purchase_date,
  warranty_status,
  previous_repairs,
  item_location_label,
  vehicle_registration,
  vehicle_make,
  vehicle_model,
  vehicle_year,
  vehicle_mileage,
  vehicle_fuel_type,
  vehicle_transmission,
  problem_description,
  structured_brief,
  preferred_repair_date,
  preferred_time_start,
  preferred_time_end,
  urgency,
  approximate_area,
  approximate_location,
  travel_distance_kilometres,
  collection_required,
  mobile_repair_required,
  inspection_required,
  maximum_callout_fee_minor,
  budget_minimum_minor,
  budget_maximum_minor,
  currency_code,
  evidence_visible_to_eligible_repairers,
  status,
  cancellation_reason,
  updated_at
) on public.repair_requests to authenticated;

create policy repair_requests_read_owner_or_eligible
  on public.repair_requests for select
  to authenticated
  using (
    deleted_at is null
    and (
      customer_id = (select auth.uid())
      or private.can_view_marketplace_request(id, (select auth.uid()))
      or exists (
        select 1 from public.jobs as j
        where j.request_id = id
          and j.repairer_id = (select auth.uid())
          and j.deleted_at is null
      )
    )
  );

create policy repair_requests_insert_customer
  on public.repair_requests for insert
  to authenticated
  with check (
    customer_id = (select auth.uid())
    and private.current_user_role() = 'customer'
    and status in ('draft', 'submitted')
    and deleted_at is null
  );

create policy repair_requests_update_owned_draft
  on public.repair_requests for update
  to authenticated
  using (customer_id = (select auth.uid()) and status = 'draft' and deleted_at is null)
  with check (
    customer_id = (select auth.uid())
    and status in ('draft', 'submitted', 'cancelled')
    and deleted_at is null
  );

create policy repair_requests_delete_owned_draft
  on public.repair_requests for delete
  to authenticated
  using (customer_id = (select auth.uid()) and status = 'draft');

grant select, insert, update, delete on public.repair_request_private_locations to authenticated;
create policy private_locations_read_authorised
  on public.repair_request_private_locations for select
  to authenticated
  using (deleted_at is null and private.can_access_private_location(request_id, (select auth.uid())));
create policy private_locations_insert_owner on public.repair_request_private_locations for insert to authenticated
  with check (customer_id = (select auth.uid()) and deleted_at is null);
create policy private_locations_update_owner_draft on public.repair_request_private_locations for update to authenticated
  using (
    customer_id = (select auth.uid())
    and deleted_at is null
    and exists (select 1 from public.repair_requests as r where r.id = request_id and r.status = 'draft')
  )
  with check (customer_id = (select auth.uid()));
create policy private_locations_delete_owner_draft on public.repair_request_private_locations for delete to authenticated
  using (
    customer_id = (select auth.uid())
    and exists (select 1 from public.repair_requests as r where r.id = request_id and r.status = 'draft')
  );

grant select, insert, update, delete on public.repair_request_symptoms, public.repair_request_media to authenticated;
create policy request_symptoms_read_authorised on public.repair_request_symptoms for select to authenticated
  using (deleted_at is null and private.can_access_request_evidence(request_id, (select auth.uid())));
create policy request_symptoms_insert_owner_draft on public.repair_request_symptoms for insert to authenticated
  with check (
    deleted_at is null and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  );
create policy request_symptoms_update_owner_draft on public.repair_request_symptoms for update to authenticated
  using (
    deleted_at is null and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  ) with check (
    deleted_at is null and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  );
create policy request_symptoms_delete_owner_draft on public.repair_request_symptoms for delete to authenticated
  using (exists (
    select 1 from public.repair_requests as r
    where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
  ));

create policy request_media_read_authorised on public.repair_request_media for select to authenticated
  using (
    deleted_at is null
    and upload_status = 'ready'
    and private.can_access_request_evidence(request_id, (select auth.uid()))
  );
create policy request_media_insert_owner_draft on public.repair_request_media for insert to authenticated
  with check (
    uploaded_by = (select auth.uid())
    and upload_status in ('pending', 'uploading')
    and deleted_at is null
    and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  );
create policy request_media_update_owner_draft on public.repair_request_media for update to authenticated
  using (
    uploaded_by = (select auth.uid())
    and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  ) with check (
    uploaded_by = (select auth.uid())
    and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  );
create policy request_media_delete_owner_draft on public.repair_request_media for delete to authenticated
  using (
    uploaded_by = (select auth.uid())
    and exists (
      select 1 from public.repair_requests as r
      where r.id = request_id and r.customer_id = (select auth.uid()) and r.status = 'draft'
    )
  );

-- AI writes are server-only; authorised parties receive validated snapshots.
grant select on public.ai_assessments, public.ai_possible_causes, public.ai_follow_up_questions to authenticated;
create policy ai_assessments_read_authorised on public.ai_assessments for select to authenticated
  using (
    validation_status = 'valid'
    and private.can_access_request_evidence(request_id, (select auth.uid()))
  );
create policy ai_possible_causes_read_authorised on public.ai_possible_causes for select to authenticated
  using (
    not hidden_from_customer
    and exists (
      select 1 from public.ai_assessments as a
      where a.id = assessment_id
        and a.validation_status = 'valid'
        and private.can_access_request_evidence(a.request_id, (select auth.uid()))
    )
  );
create policy ai_follow_up_questions_read_owner on public.ai_follow_up_questions for select to authenticated
  using (exists (
    select 1 from public.ai_assessments as a
    join public.repair_requests as r on r.id = a.request_id
    where a.id = assessment_id and r.customer_id = (select auth.uid())
  ));

-- Quotes and line items.
grant select, insert, delete on public.quotes to authenticated;
grant update (
  status,
  inspection_fee_minor,
  callout_fee_minor,
  labour_minimum_minor,
  labour_maximum_minor,
  parts_minimum_minor,
  parts_maximum_minor,
  other_charges_minimum_minor,
  other_charges_maximum_minor,
  currency_code,
  earliest_availability,
  estimated_duration_minutes,
  collection_available,
  mobile_repair_available,
  warranty_days,
  expires_at,
  additional_comments,
  assumptions,
  exclusions,
  updated_at
) on public.quotes to authenticated;

create policy quotes_read_parties
  on public.quotes for select to authenticated
  using (
    deleted_at is null and (
      repairer_id = (select auth.uid())
      or exists (
        select 1 from public.repair_requests as r
        where r.id = request_id and r.customer_id = (select auth.uid())
      )
    )
  );
create policy quotes_insert_eligible_repairer on public.quotes for insert to authenticated
  with check (
    repairer_id = (select auth.uid())
    and private.current_user_role() = 'repairer'
    and status in ('draft', 'submitted')
    and deleted_at is null
    and private.can_view_marketplace_request(request_id, (select auth.uid()))
  );
create policy quotes_update_own_active on public.quotes for update to authenticated
  using (
    repairer_id = (select auth.uid())
    and status in ('draft', 'submitted')
    and deleted_at is null
  ) with check (
    repairer_id = (select auth.uid())
    and status in ('draft', 'submitted', 'withdrawn')
    and deleted_at is null
  );
create policy quotes_delete_own_draft on public.quotes for delete to authenticated
  using (repairer_id = (select auth.uid()) and status = 'draft');

grant select, insert, update, delete on public.quote_items to authenticated;
create policy quote_items_read_parties on public.quote_items for select to authenticated
  using (deleted_at is null and exists (
    select 1 from public.quotes as q
    join public.repair_requests as r on r.id = q.request_id
    where q.id = quote_id
      and (q.repairer_id = (select auth.uid()) or r.customer_id = (select auth.uid()))
  ));
create policy quote_items_insert_quote_owner on public.quote_items for insert to authenticated
  with check (deleted_at is null and exists (
    select 1 from public.quotes as q
    where q.id = quote_id and q.repairer_id = (select auth.uid()) and q.status = 'draft'
  ));
create policy quote_items_update_quote_owner on public.quote_items for update to authenticated
  using (exists (
    select 1 from public.quotes as q
    where q.id = quote_id and q.repairer_id = (select auth.uid()) and q.status = 'draft'
  )) with check (
    deleted_at is null and exists (
      select 1 from public.quotes as q
      where q.id = quote_id and q.repairer_id = (select auth.uid()) and q.status = 'draft'
    )
  );
create policy quote_items_delete_quote_owner on public.quote_items for delete to authenticated
  using (exists (
    select 1 from public.quotes as q
    where q.id = quote_id and q.repairer_id = (select auth.uid()) and q.status = 'draft'
  ));

-- Jobs, appointments, conversations, and messages are participant-only.
grant select on public.jobs, public.job_status_history to authenticated;
create policy jobs_read_parties on public.jobs for select to authenticated
  using (
    deleted_at is null
    and (customer_id = (select auth.uid()) or repairer_id = (select auth.uid()))
  );
create policy job_status_history_read_parties on public.job_status_history for select to authenticated
  using (exists (
    select 1 from public.jobs as j
    where j.id = job_id
      and (j.customer_id = (select auth.uid()) or j.repairer_id = (select auth.uid()))
      and j.deleted_at is null
  ));

grant select, insert, delete on public.appointments to authenticated;
grant update (
  kind,
  status,
  starts_at,
  ends_at,
  timezone,
  location_address,
  location_released,
  response_message,
  responded_at,
  updated_at,
  deleted_at
) on public.appointments to authenticated;
create policy appointments_read_parties on public.appointments for select to authenticated
  using (deleted_at is null and exists (
    select 1 from public.jobs as j
    where j.id = job_id and (j.customer_id = (select auth.uid()) or j.repairer_id = (select auth.uid()))
  ));
create policy appointments_insert_participant on public.appointments for insert to authenticated
  with check (
    proposed_by = (select auth.uid())
    and status = 'proposed'
    and not location_released
    and deleted_at is null
    and exists (
      select 1 from public.jobs as j
      where j.id = job_id
        and j.request_id = request_id
        and (j.customer_id = (select auth.uid()) or j.repairer_id = (select auth.uid()))
    )
  );
create policy appointments_update_participant on public.appointments for update to authenticated
  using (deleted_at is null and exists (
    select 1 from public.jobs as j
    where j.id = job_id and (j.customer_id = (select auth.uid()) or j.repairer_id = (select auth.uid()))
  )) with check (exists (
    select 1 from public.jobs as j
    where j.id = job_id and (j.customer_id = (select auth.uid()) or j.repairer_id = (select auth.uid()))
  ));
create policy appointments_delete_proposer on public.appointments for delete to authenticated
  using (proposed_by = (select auth.uid()) and status = 'proposed');

grant select on public.conversations to authenticated;
create policy conversations_read_participants on public.conversations for select to authenticated
  using (deleted_at is null and private.can_access_conversation(id, (select auth.uid())));

grant select on public.conversation_participants to authenticated;
grant update (last_read_at, is_muted, updated_at) on public.conversation_participants to authenticated;
create policy conversation_participants_read_conversation on public.conversation_participants for select to authenticated
  using (private.can_access_conversation(conversation_id, (select auth.uid())));
create policy conversation_participants_update_self on public.conversation_participants for update to authenticated
  using (participant_id = (select auth.uid()) and left_at is null)
  with check (participant_id = (select auth.uid()) and left_at is null);

grant select, insert on public.messages to authenticated;
grant update (body, edited_at, deleted_at, updated_at) on public.messages to authenticated;
create policy messages_read_participants on public.messages for select to authenticated
  using (private.can_access_conversation(conversation_id, (select auth.uid())));
create policy messages_insert_participant on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and private.can_access_conversation(conversation_id, (select auth.uid()))
  );
create policy messages_update_sender on public.messages for update to authenticated
  using (sender_id = (select auth.uid()) and deleted_at is null)
  with check (sender_id = (select auth.uid()));

-- Reviews are immutable user submissions tied to completed jobs.
grant select, insert on public.reviews to authenticated;
create policy reviews_read_authorised on public.reviews for select to authenticated
  using (
    deleted_at is null
    and (
      direction = 'customer_to_repairer'
      or author_id = (select auth.uid())
      or reviewed_user_id = (select auth.uid())
    )
  );
create policy reviews_insert_author on public.reviews for insert to authenticated
  with check (author_id = (select auth.uid()) and deleted_at is null);

-- User-owned notifications and trust/safety records.
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
create policy notifications_read_own on public.notifications for select to authenticated
  using (recipient_id = (select auth.uid()) and deleted_at is null);
create policy notifications_mark_own_read on public.notifications for update to authenticated
  using (recipient_id = (select auth.uid()) and deleted_at is null)
  with check (recipient_id = (select auth.uid()) and deleted_at is null);

grant select, insert, delete on public.saved_repairers to authenticated;
create policy saved_repairers_read_own on public.saved_repairers for select to authenticated
  using (customer_id = (select auth.uid()));
create policy saved_repairers_insert_own on public.saved_repairers for insert to authenticated
  with check (customer_id = (select auth.uid()) and private.current_user_role() = 'customer');
create policy saved_repairers_delete_own on public.saved_repairers for delete to authenticated
  using (customer_id = (select auth.uid()));

grant select, insert on public.reports to authenticated;
create policy reports_read_own on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));
create policy reports_insert_own on public.reports for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and status = 'submitted'
    and reviewed_by is null
    and reviewed_at is null
    and resolution_notes is null
  );

grant select, insert, delete on public.blocked_users to authenticated;
create policy blocked_users_read_own on public.blocked_users for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy blocked_users_insert_own on public.blocked_users for insert to authenticated
  with check (blocker_id = (select auth.uid()));
create policy blocked_users_delete_own on public.blocked_users for delete to authenticated
  using (blocker_id = (select auth.uid()));

-- audit_events and ai_usage_events intentionally have no client policy/grant.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select is(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'public'
      and table_type = 'BASE TABLE'
      and table_name = any(array[
        'profiles', 'customer_profiles', 'repairer_profiles',
        'repair_categories', 'repair_subcategories',
        'repairer_specialisations', 'repairer_certifications',
        'service_areas', 'availability_slots', 'idempotency_keys',
        'audit_events', 'repair_requests',
        'repair_request_private_locations', 'repair_request_symptoms',
        'repair_request_media', 'ai_assessments', 'ai_possible_causes',
        'ai_follow_up_questions', 'quotes', 'quote_items', 'jobs',
        'job_status_history', 'appointments', 'conversations',
        'conversation_participants', 'messages', 'reviews', 'notifications',
        'saved_repairers', 'reports', 'blocked_users', 'ai_usage_events'
      ])
  ),
  32::bigint,
  'all required and supporting public tables exist'
);

select ok(
  not exists (
    select 1
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relrowsecurity
  ),
  'RLS is enabled on every public table'
);

select ok(
  not exists (
    select 1
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relforcerowsecurity
  ),
  'RLS is forced on every public table'
);

select is(
  (
    select count(*) from storage.buckets
    where id = any(array[
      'profile-images', 'business-logos', 'repair-request-images',
      'repair-request-videos', 'repair-request-audio',
      'repair-request-documents',
      'message-attachments', 'certifications', 'review-media'
    ]) and not public
  ),
  9::bigint,
  'all nine application buckets are private'
);

select ok(
  to_regprocedure('public.claim_role(text)') is not null
  and to_regprocedure('public.complete_customer_onboarding(jsonb)') is not null
  and to_regprocedure('public.submit_repairer_onboarding(jsonb)') is not null,
  'Stage 3 onboarding RPC contract exists'
);

select ok(
  to_regprocedure('public.accept_quote(uuid,text)') is not null
  and to_regprocedure('public.set_job_status(uuid,public.job_status,text)') is not null,
  'controlled quote and job RPCs exist'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT')
  and has_table_privilege('anon', 'public.repair_categories', 'SELECT'),
  'anonymous access is limited to catalogue data'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'fixbrief_private_objects_%'
  ),
  4::bigint,
  'storage objects have read, insert, update, and delete policies'
);

select * from finish();
rollback;

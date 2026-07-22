begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select ok(
  to_regprocedure('public.get_jobs()') is not null
  and to_regprocedure('public.get_job_details(uuid)') is not null
  and to_regprocedure('public.submit_job_review(uuid,jsonb)') is not null
  and to_regprocedure('public.respond_to_job_review(uuid,text)') is not null,
  'Stage 10 job and review RPC contract exists'
);

select ok(
  not has_function_privilege('anon', 'public.get_jobs()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_jobs()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.submit_job_review(uuid,jsonb)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.submit_job_review(uuid,jsonb)', 'EXECUTE')
  and not has_table_privilege('authenticated', 'public.reviews', 'INSERT'),
  'Stage 10 reads are authenticated and review mutations are RPC-only'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000002';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}';

select ok(
  jsonb_array_length(public.get_jobs()) >= 1
  and public.get_jobs()::text !~* '(phone_number|business_email|business_address)',
  'customer receives only participant jobs without private contact fields'
);

select ok(
  public.get_job_details('80000000-0000-4000-8000-000000000001') ->> 'item_name' <> ''
  and jsonb_array_length(
    public.get_job_details('80000000-0000-4000-8000-000000000001') -> 'history'
  ) >= 1
  and jsonb_array_length(
    public.get_job_details('80000000-0000-4000-8000-000000000001') -> 'reviews'
  ) = 1,
  'job detail includes its item, immutable status history, and reviews'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.get_job_details('80000000-0000-4000-8000-000000000001')$$,
  'P0002',
  'Job not found.',
  'non-participants cannot load job details'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '20000000-0000-4000-8000-000000000003';
set local "request.jwt.claims" = '{"sub":"20000000-0000-4000-8000-000000000003","role":"authenticated"}';

select is(
  public.submit_job_review(
    '80000000-0000-4000-8000-000000000001',
    jsonb_build_object(
      'overall_rating', 5,
      'communication_rating', 5,
      'description_accuracy_rating', 5,
      'attendance_rating', 4,
      'location_accessibility_rating', 4,
      'comment', 'Accurate description and clear access instructions.'
    )
  ) ->> 'direction',
  'repairer_to_customer',
  'repair professional can submit one completed-job customer review'
);

select is(
  public.respond_to_job_review(
    '90000000-0000-4000-8000-000000000001',
    'Thank you for trusting us with your repair.'
  ) ->> 'repairer_response',
  'Thank you for trusting us with your repair.',
  'reviewed repair professional can publish one response'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000002';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}';

select is(
  jsonb_array_length(
    public.get_job_details('80000000-0000-4000-8000-000000000001') -> 'reviews'
  ),
  2,
  'both participant review directions are visible on completed job history'
);

reset role;
select * from finish();
rollback;

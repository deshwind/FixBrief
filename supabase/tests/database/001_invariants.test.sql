begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select is(
  (select total_minimum_minor from public.quotes where id = '60000000-0000-4000-8000-000000000001'),
  13500,
  'quote minimum is derived from component amounts'
);

select is(
  (select total_maximum_minor from public.quotes where id = '60000000-0000-4000-8000-000000000001'),
  47500,
  'quote maximum is derived from component amounts'
);

select is(
  (select average_rating from public.repairer_profiles where user_id = '20000000-0000-4000-8000-000000000003'),
  5.00::numeric,
  'repairer rating is derived from eligible reviews'
);

select is(
  (select review_count from public.repairer_profiles where user_id = '20000000-0000-4000-8000-000000000003'),
  1,
  'repairer review count is derived'
);

select is(
  (select completed_job_count from public.repairer_profiles where user_id = '20000000-0000-4000-8000-000000000003'),
  1,
  'completed job count is derived'
);

select is(
  (select count(*) from public.job_status_history where job_id = '80000000-0000-4000-8000-000000000001'),
  1::bigint,
  'job creation records initial status history'
);

select is(
  (select status from public.repair_requests where id = '30000000-0000-4000-8000-000000000003'),
  'quotes_received'::public.request_status,
  'submitted quote advances a published request to quotes received'
);

select * from finish();
rollback;

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

set local role anon;
select is((select count(*) from public.repair_categories), 23::bigint, 'anonymous users can read active categories');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*) from public.customer_profiles), 1::bigint, 'customer reads only their own customer profile');
select is((select count(*) from public.repair_requests), 4::bigint, 'customer reads only their own requests');
select is((select count(*) from public.quotes), 2::bigint, 'customer reads quotes only for owned requests');
select is((select count(*) from public.repairer_certifications), 0::bigint, 'customer cannot read repairer certification evidence');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '20000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*) from public.customer_profiles), 0::bigint, 'repairer cannot read private customer profiles');
select is((select count(*) from public.repair_requests), 1::bigint, 'repairer sees only eligible marketplace requests');
select is((select count(*) from public.quotes), 1::bigint, 'repairer sees only their own quotes');
select is((select count(*) from public.conversations), 1::bigint, 'repairer sees only participated conversations');
select ok(
  not private.can_access_private_location(
    '30000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000001'
  ),
  'unaccepted repairer cannot access an exact customer location'
);
reset role;

select * from finish();
rollback;

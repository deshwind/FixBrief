begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select ok(
  to_regprocedure('public.get_repairer_quote(uuid)') is not null
  and to_regprocedure('public.get_repairer_quotes()') is not null
  and to_regprocedure('public.save_quote_draft(uuid,uuid,jsonb)') is not null
  and to_regprocedure('public.submit_quote(uuid)') is not null
  and to_regprocedure('public.withdraw_quote(uuid)') is not null
  and to_regprocedure('public.get_customer_quote_comparison(uuid)') is not null,
  'Stage 8 quote workflow RPC contract exists'
);

select ok(
  not has_function_privilege(
    'anon', 'public.get_customer_quote_comparison(uuid)', 'EXECUTE'
  )
  and has_function_privilege(
    'authenticated', 'public.get_customer_quote_comparison(uuid)', 'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.save_quote_draft(uuid,uuid,jsonb)', 'EXECUTE'
  ),
  'quote authoring and comparison are authenticated only'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '20000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  public.get_repairer_quote(
    '30000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'submitted',
  'repairer can retrieve their own submitted quote'
);

select ok(
  (public.get_repairer_quote(
    '30000000-0000-4000-8000-000000000001'
  ) ->> 'total_minimum_minor')::integer = 13500
  and (public.get_repairer_quote(
    '30000000-0000-4000-8000-000000000001'
  ) ->> 'total_maximum_minor')::integer = 47500,
  'quote totals are calculated from their component ranges'
);

select is(
  jsonb_array_length(public.get_repairer_quotes()),
  1,
  'repairer quote list is scoped to the signed-in repairer'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  jsonb_array_length(public.get_customer_quote_comparison(
    '30000000-0000-4000-8000-000000000001'
  ) -> 'quotes'),
  3,
  'request owner receives all three submitted comparison quotes'
);

select ok(
  not (public.get_customer_quote_comparison(
    '30000000-0000-4000-8000-000000000001'
  )::text ~* '(phone_number|business_email|business_address|business_location)'),
  'customer quote comparison omits private repairer contact and location data'
);

select ok(
  public.get_customer_quote_comparison(
    '30000000-0000-4000-8000-000000000001'
  )::text !~* 'cheapest'
  and exists (
    select 1
    from jsonb_array_elements(public.get_customer_quote_comparison(
      '30000000-0000-4000-8000-000000000001'
    ) -> 'quotes') as quote
    where (quote ->> 'is_recommended')::boolean
      and jsonb_array_length(quote -> 'recommendation_reasons') > 0
  ),
  'overall-fit recommendation is explained and never labelled cheapest'
);

select ok(
  public.accept_quote(
    '60000000-0000-4000-8000-000000000001',
    'stage8-accept-quote-0001'
  ) is not null
  and exists (
    select 1 from public.jobs as j
    where j.request_id = '30000000-0000-4000-8000-000000000001'
      and j.accepted_quote_id = '60000000-0000-4000-8000-000000000001'
  ),
  'customer acceptance atomically creates the job for the selected quote'
);

reset role;
select * from finish();
rollback;

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select ok(
  to_regprocedure(
    'public.get_ranked_marketplace_requests(uuid,public.urgency_level,numeric,text,boolean,boolean,text,integer,integer)'
  ) is not null
  and to_regprocedure('public.get_marketplace_request_detail(uuid)') is not null
  and to_regprocedure('public.get_repairer_marketplace_profile(uuid)') is not null
  and to_regprocedure('public.get_repairer_marketplace_summary()') is not null,
  'Stage 7 marketplace RPC contract exists'
);

select ok(
  private.marketplace_safe_text(
    'Call 07700 900123 or test@example.com at 12 Example Road'
  ) not like '%07700%'
  and private.marketplace_safe_text(
    'Call 07700 900123 or test@example.com at 12 Example Road'
  ) not like '%example.com%'
  and private.marketplace_safe_text(
    'Call 07700 900123 or test@example.com at 12 Example Road'
  ) not like '%Example Road%',
  'marketplace free text redacts phone, email, and street-address patterns'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.get_ranked_marketplace_requests(uuid,public.urgency_level,numeric,text,boolean,boolean,text,integer,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_ranked_marketplace_requests(uuid,public.urgency_level,numeric,text,boolean,boolean,text,integer,integer)',
    'EXECUTE'
  ),
  'ranked marketplace access is authenticated only'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '20000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (
    select count(*)
    from public.get_ranked_marketplace_requests(
      null, null, null, null, false, false, 'best_match', 50, 0
    )
  ),
  1::bigint,
  'verified repairer receives only eligible matching requests'
);

select ok(
  (
    select match_score > 0
      and cardinality(match_reasons) >= 2
      and approximate_area is not null
    from public.get_ranked_marketplace_requests(
      null, null, null, null, false, false, 'best_match', 50, 0
    )
    limit 1
  ),
  'ranked result has an explainable score and approximate area'
);

select ok(
  not (
    public.get_marketplace_request_detail(
      '30000000-0000-4000-8000-000000000001'
    )::text ~* '(customer_id|exact_address|phone_number|customer_profiles)'
  ),
  'marketplace request detail omits customer identity and precise location fields'
);

select ok(
  not (
    public.get_repairer_marketplace_profile(
      '20000000-0000-4000-8000-000000000001'
    )::text ~* '(phone_number|business_email|business_address|business_location)'
  ),
  'public repairer profile omits private contact and precise location fields'
);

select ok(
  (public.get_repairer_marketplace_summary() ? 'new_match_count')
  and (public.get_repairer_marketplace_summary() ? 'active_job_count'),
  'repairer dashboard summary provides marketplace and work counters'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (
    select count(*)
    from public.get_ranked_marketplace_requests(
      null, null, null, null, false, false, 'best_match', 50, 0
    )
  ),
  0::bigint,
  'customer accounts cannot receive the repairer marketplace feed'
);

reset role;
select * from finish();
rollback;

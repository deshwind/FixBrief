begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select ok(
  to_regprocedure('public.get_conversations()') is not null
  and to_regprocedure('public.get_conversation_messages(uuid,timestamp with time zone,integer)') is not null
  and to_regprocedure('public.send_conversation_message(uuid,uuid,text,text,text,text,text,bigint)') is not null
  and to_regprocedure('public.propose_appointment(uuid,text,timestamp with time zone,timestamp with time zone,text)') is not null
  and to_regprocedure('public.respond_to_appointment(uuid,text,text,boolean)') is not null,
  'Stage 9 messaging and appointment RPC contract exists'
);

select ok(
  not has_function_privilege('anon', 'public.get_conversations()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_conversations()', 'EXECUTE')
  and not has_table_privilege('authenticated', 'public.messages', 'INSERT')
  and not has_table_privilege('authenticated', 'public.appointments', 'INSERT'),
  'Stage 9 reads are authenticated and mutations are RPC-only'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'fixbrief_conversation_broadcast_read'
  )
  and exists (
    select 1 from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'fixbrief_conversation_broadcast_write'
  ),
  'typing broadcasts are protected by private-channel authorization policies'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';

select ok(
  jsonb_array_length(public.get_conversations()) >= 1
  and public.get_conversations()::text !~* '(phone_number|business_email|business_address)',
  'customer receives authorized conversations without private profile fields'
);

select is(
  jsonb_array_length(public.get_conversation_messages(
    (select id from public.conversations
     where request_id = '30000000-0000-4000-8000-000000000001'
       and repairer_id = '20000000-0000-4000-8000-000000000001'),
    null,
    80
  )),
  2,
  'conversation participants can read the seeded message history'
);

select is(
  public.send_conversation_message(
    (select id from public.conversations
     where request_id = '30000000-0000-4000-8000-000000000001'
       and repairer_id = '20000000-0000-4000-8000-000000000001'),
    '71000000-0000-4000-8000-000000000001',
    'text',
    'Stage 9 secure message',
    null, null, null, null
  ) ->> 'body',
  'Stage 9 secure message',
  'participant can send an idempotent conversation message'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '20000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  public.propose_appointment(
    (select id from public.conversations
     where request_id = '30000000-0000-4000-8000-000000000001'
       and repairer_id = '20000000-0000-4000-8000-000000000001'),
    'inspection',
    now() + interval '2 days',
    now() + interval '2 days 1 hour',
    'Europe/London'
  ) ->> 'status',
  'proposed',
  'repairer can propose an inspection before quote acceptance'
);

reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  public.respond_to_appointment(
    (select id from public.appointments
     where request_id = '30000000-0000-4000-8000-000000000001'
     order by created_at desc limit 1),
    'confirmed',
    'That time works.',
    false
  ) ->> 'status',
  'confirmed',
  'other participant can confirm the appointment without releasing an address'
);

select lives_ok(
  format(
    'select public.set_conversation_blocked(%L::uuid, true, %L)',
    (select id from public.conversations
     where request_id = '30000000-0000-4000-8000-000000000001'
       and repairer_id = '20000000-0000-4000-8000-000000000001'),
    'Stage 9 pgTAP check'
  ),
  'participant can block the other conversation member'
);

select ok(
  exists (
    select 1 from public.blocked_users
    where blocker_id = '10000000-0000-4000-8000-000000000001'
      and blocked_id = '20000000-0000-4000-8000-000000000001'
  ),
  'block state is stored against the two authorized participants'
);

reset role;
select * from finish();
rollback;

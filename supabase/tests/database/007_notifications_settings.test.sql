begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

insert into public.notifications (
  id, recipient_id, notification_type, title, body, related_entity_type,
  related_entity_id, deep_link, dedupe_key
) values (
  'a1000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  'new_message',
  'Stage 11 notification',
  'A secure notification for the database test.',
  'conversation',
  null,
  '/messages/50000000-0000-4000-8000-000000000001',
  'stage11-pgtap-notification'
) on conflict do nothing;

insert into public.blocked_users (blocker_id, blocked_id, reason)
values (
  '10000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003',
  'Stage 11 pgTAP check'
) on conflict do nothing;

select ok(
  to_regclass('public.notification_preferences') is not null
  and to_regclass('public.data_export_requests') is not null
  and to_regclass('public.account_deletion_requests') is not null
  and to_regprocedure('public.get_notifications(integer,timestamp with time zone)') is not null
  and to_regprocedure('public.get_settings_overview()') is not null,
  'Stage 11 tables and RPC contract exist'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.get_notifications(integer,timestamp with time zone)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_notifications(integer,timestamp with time zone)',
    'EXECUTE'
  )
  and not has_table_privilege('authenticated', 'public.notifications', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.notification_preferences', 'INSERT'),
  'notification and settings mutations are authenticated RPC-only operations'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000002';
set local "request.jwt.claims" = '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}';

select ok(
  public.get_notifications() @> '[{"id":"a1000000-0000-4000-8000-000000000001"}]'::jsonb
  and public.get_notifications()::text !~* '(recipient_id|push_sent_at|email_sent_at)',
  'notification inbox contains only presentation-safe recipient data'
);

select lives_ok(
  $$select public.mark_notification_read('a1000000-0000-4000-8000-000000000001')$$,
  'recipient can mark an owned notification read'
);

select ok(
  exists (
    select 1 from public.notifications
    where id = 'a1000000-0000-4000-8000-000000000001' and read_at is not null
  )
  and public.mark_all_notifications_read() >= 0,
  'read state is persisted and all notifications can be acknowledged'
);

select is(
  public.update_notification_preferences(
    '{"push_enabled":false,"email_enabled":true,"new_messages":true,"quote_updates":false,"appointment_reminders":true,"job_updates":true,"matching_requests":false}'::jsonb
  ) ->> 'push_enabled',
  'false',
  'notification delivery preferences can be updated securely'
);

select ok(
  (public.get_settings_overview() -> 'preferences' ->> 'quote_updates')::boolean is false
  and public.get_settings_overview() ? 'latest_export'
  and public.get_settings_overview() ? 'deletion_request',
  'settings overview returns preferences and privacy-request structure'
);

select is(
  public.request_data_export() ->> 'id',
  public.request_data_export() ->> 'id',
  'repeated export requests reuse the active request'
);

with requested as materialized (
  select public.request_account_deletion(
    'DELETE',
    'Stage 11 pgTAP check'
  ) as result
), cancelled as materialized (
  select public.cancel_account_deletion() from requested
)
select ok(
  (select result ->> 'status' from requested) = 'pending'
  and (select count(*) from cancelled) = 1
  and (
    select account_status = 'active'
    from public.profiles
    where id = '10000000-0000-4000-8000-000000000002'
  ),
  'account deletion is scheduled with a recovery period and can be cancelled'
);

with initial_state as materialized (
  select public.get_blocked_users() as result
), unblocked as materialized (
  select public.unblock_user('20000000-0000-4000-8000-000000000003')
  from initial_state
), final_state as materialized (
  select public.get_blocked_users() as result from unblocked
)
select ok(
  (select result from initial_state)
    @> '[{"user_id":"20000000-0000-4000-8000-000000000003"}]'::jsonb
  and (select count(*) from unblocked) = 1
  and jsonb_array_length((select result from final_state)) = 0,
  'blocked-user settings reveal safe display data and support unblocking'
);

reset role;
select * from finish();
rollback;

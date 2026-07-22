-- FixBrief Stage 11: in-app notification APIs, user preferences, privacy
-- requests, blocked-user management, and account deletion scheduling.

create table public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  new_messages boolean not null default true,
  quote_updates boolean not null default true,
  appointment_reminders boolean not null default true,
  job_updates boolean not null default true,
  matching_requests boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.data_export_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  export_format text not null default 'json',
  storage_path text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  download_expires_at timestamptz,
  failure_reason text,
  constraint data_export_status check (
    status in ('pending', 'processing', 'ready', 'expired', 'failed')
  ),
  constraint data_export_format check (export_format in ('json', 'zip')),
  constraint data_export_failure_length check (
    failure_reason is null or char_length(failure_reason) <= 1000
  ),
  constraint data_export_ready_consistency check (
    status <> 'ready'
    or (
      storage_path is not null
      and completed_at is not null
      and download_expires_at is not null
    )
  )
);

create unique index data_export_one_open_request
  on public.data_export_requests (user_id)
  where status in ('pending', 'processing');
create index data_export_user_history
  on public.data_export_requests (user_id, requested_at desc);

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  reason text,
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default (now() + interval '14 days'),
  cancelled_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  constraint account_deletion_status check (
    status in ('pending', 'cancelled', 'processing', 'completed')
  ),
  constraint account_deletion_reason_length check (
    reason is null or char_length(reason) <= 1000
  ),
  constraint account_deletion_schedule check (
    scheduled_for >= requested_at + interval '24 hours'
  )
);

create unique index account_deletion_one_active_request
  on public.account_deletion_requests (user_id)
  where status in ('pending', 'processing');
create index account_deletion_user_history
  on public.account_deletion_requests (user_id, requested_at desc);

-- Preserve the notification choices captured during customer onboarding and
-- keep the legacy profile columns in sync while clients move to this table.
insert into public.notification_preferences (
  user_id,
  push_enabled,
  email_enabled
)
select
  cp.user_id,
  cp.push_notifications,
  cp.email_notifications
from public.customer_profiles as cp
on conflict (user_id) do nothing;

create or replace function private.sync_customer_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.notification_preferences (
    user_id,
    push_enabled,
    email_enabled
  ) values (
    new.user_id,
    new.push_notifications,
    new.email_notifications
  )
  on conflict (user_id) do update set
    push_enabled = excluded.push_enabled,
    email_enabled = excluded.email_enabled;

  return new;
end;
$$;

create trigger sync_customer_notification_preferences
  after insert or update of push_notifications, email_notifications
  on public.customer_profiles
  for each row execute function private.sync_customer_notification_preferences();

create trigger set_notification_preferences_updated_at
  before update on public.notification_preferences
  for each row execute function private.set_updated_at();

alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;
alter table public.data_export_requests enable row level security;
alter table public.data_export_requests force row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.account_deletion_requests force row level security;

create policy notification_preferences_read_own
  on public.notification_preferences for select to authenticated
  using (user_id = (select auth.uid()));
create policy data_export_requests_read_own
  on public.data_export_requests for select to authenticated
  using (user_id = (select auth.uid()));
create policy account_deletion_requests_read_own
  on public.account_deletion_requests for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.notification_preferences to authenticated;
grant select on public.data_export_requests to authenticated;
grant select on public.account_deletion_requests to authenticated;

create or replace function private.notification_json(
  target_notification public.notifications
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'id', target_notification.id,
    'notification_type', target_notification.notification_type,
    'title', target_notification.title,
    'body', target_notification.body,
    'related_entity_type', target_notification.related_entity_type,
    'related_entity_id', target_notification.related_entity_id,
    'deep_link', target_notification.deep_link,
    'read_at', target_notification.read_at,
    'created_at', target_notification.created_at
  );
$$;

create or replace function private.notification_preferences_json(
  target_preferences public.notification_preferences
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'push_enabled', target_preferences.push_enabled,
    'email_enabled', target_preferences.email_enabled,
    'new_messages', target_preferences.new_messages,
    'quote_updates', target_preferences.quote_updates,
    'appointment_reminders', target_preferences.appointment_reminders,
    'job_updates', target_preferences.job_updates,
    'matching_requests', target_preferences.matching_requests,
    'updated_at', target_preferences.updated_at
  );
$$;

create or replace function public.get_notifications(
  page_size integer default 50,
  before_time timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if page_size not between 1 and 100 then
    raise exception 'Notification page size must be between 1 and 100.' using errcode = '22023';
  end if;

  return coalesce(
    (
      select jsonb_agg(private.notification_json(page.notification) order by page.created_at desc)
      from (
        select n as notification, n.created_at
        from public.notifications as n
        where n.recipient_id = caller_id
          and n.deleted_at is null
          and (n.expires_at is null or n.expires_at > now())
          and (before_time is null or n.created_at < before_time)
        order by n.created_at desc
        limit page_size
      ) as page
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.mark_notification_read(
  target_notification_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = target_notification_id
    and recipient_id = caller_id
    and deleted_at is null;
  if not found then
    raise exception 'Notification not found.' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  affected integer;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  update public.notifications
  set read_at = now()
  where recipient_id = caller_id
    and read_at is null
    and deleted_at is null;
  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.get_settings_overview()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  user_preferences public.notification_preferences%rowtype;
  latest_export jsonb;
  deletion_request jsonb;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  insert into public.notification_preferences (user_id)
  values (caller_id)
  on conflict (user_id) do nothing;

  select * into user_preferences
  from public.notification_preferences as p
  where p.user_id = caller_id;

  select jsonb_build_object(
    'id', e.id,
    'status', e.status,
    'requested_at', e.requested_at,
    'completed_at', e.completed_at,
    'download_expires_at', e.download_expires_at
  ) into latest_export
  from public.data_export_requests as e
  where e.user_id = caller_id
  order by e.requested_at desc
  limit 1;

  select jsonb_build_object(
    'id', d.id,
    'status', d.status,
    'requested_at', d.requested_at,
    'scheduled_for', d.scheduled_for
  ) into deletion_request
  from public.account_deletion_requests as d
  where d.user_id = caller_id and d.status in ('pending', 'processing')
  order by d.requested_at desc
  limit 1;

  return jsonb_build_object(
    'preferences', private.notification_preferences_json(user_preferences),
    'latest_export', latest_export,
    'deletion_request', deletion_request
  );
end;
$$;

create or replace function public.update_notification_preferences(
  preferences jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  updated_preferences public.notification_preferences%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if preferences is null or jsonb_typeof(preferences) <> 'object' then
    raise exception 'Notification preferences must be an object.' using errcode = '22023';
  end if;

  insert into public.notification_preferences (
    user_id,
    push_enabled,
    email_enabled,
    new_messages,
    quote_updates,
    appointment_reminders,
    job_updates,
    matching_requests
  ) values (
    caller_id,
    coalesce((preferences ->> 'push_enabled')::boolean, true),
    coalesce((preferences ->> 'email_enabled')::boolean, true),
    coalesce((preferences ->> 'new_messages')::boolean, true),
    coalesce((preferences ->> 'quote_updates')::boolean, true),
    coalesce((preferences ->> 'appointment_reminders')::boolean, true),
    coalesce((preferences ->> 'job_updates')::boolean, true),
    coalesce((preferences ->> 'matching_requests')::boolean, true)
  )
  on conflict (user_id) do update set
    push_enabled = excluded.push_enabled,
    email_enabled = excluded.email_enabled,
    new_messages = excluded.new_messages,
    quote_updates = excluded.quote_updates,
    appointment_reminders = excluded.appointment_reminders,
    job_updates = excluded.job_updates,
    matching_requests = excluded.matching_requests
  returning * into updated_preferences;

  update public.customer_profiles
  set
    push_notifications = updated_preferences.push_enabled,
    email_notifications = updated_preferences.email_enabled
  where user_id = caller_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'settings.notifications_updated', 'profile', caller_id);

  return private.notification_preferences_json(updated_preferences);
end;
$$;

create or replace function public.request_data_export()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  target_request public.data_export_requests%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  select * into target_request
  from public.data_export_requests as e
  where e.user_id = caller_id and e.status in ('pending', 'processing')
  order by e.requested_at desc
  limit 1;

  if not found then
    insert into public.data_export_requests (user_id)
    values (caller_id)
    returning * into target_request;

    insert into public.audit_events (actor_id, action, entity_type, entity_id)
    values (caller_id, 'account.data_export_requested', 'data_export', target_request.id);
  end if;

  return jsonb_build_object(
    'id', target_request.id,
    'status', target_request.status,
    'requested_at', target_request.requested_at,
    'completed_at', target_request.completed_at,
    'download_expires_at', target_request.download_expires_at
  );
end;
$$;

create or replace function public.request_account_deletion(
  confirmation text,
  reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  normalized_reason text := nullif(trim(reason), '');
  target_request public.account_deletion_requests%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if confirmation is distinct from 'DELETE' then
    raise exception 'Type DELETE to confirm account deletion.' using errcode = '22023';
  end if;
  if normalized_reason is not null and char_length(normalized_reason) > 1000 then
    raise exception 'Deletion reason must be under 1,000 characters.' using errcode = '22023';
  end if;

  select * into target_request
  from public.account_deletion_requests as d
  where d.user_id = caller_id and d.status in ('pending', 'processing')
  order by d.requested_at desc
  limit 1
  for update;

  if not found then
    insert into public.account_deletion_requests (user_id, reason)
    values (caller_id, normalized_reason)
    returning * into target_request;
  end if;

  update public.profiles
  set account_status = 'deletion_requested', updated_at = now(), updated_by = caller_id
  where id = caller_id and account_status = 'active';

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    caller_id,
    'account.deletion_requested',
    'account_deletion',
    target_request.id,
    jsonb_build_object('scheduled_for', target_request.scheduled_for)
  );

  return jsonb_build_object(
    'id', target_request.id,
    'status', target_request.status,
    'requested_at', target_request.requested_at,
    'scheduled_for', target_request.scheduled_for
  );
end;
$$;

create or replace function public.cancel_account_deletion()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  target_id uuid;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  update public.account_deletion_requests
  set status = 'cancelled', cancelled_at = now()
  where user_id = caller_id and status = 'pending'
  returning id into target_id;
  if not found then
    raise exception 'No cancellable deletion request was found.' using errcode = 'P0002';
  end if;

  update public.profiles
  set account_status = 'active', updated_at = now(), updated_by = caller_id
  where id = caller_id and account_status = 'deletion_requested';

  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'account.deletion_cancelled', 'account_deletion', target_id);
end;
$$;

create or replace function public.get_blocked_users()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'user_id', b.blocked_id,
          'display_name', coalesce(
            rp.business_name,
            cp.full_name,
            rp.full_name,
            p.display_name,
            'FixBrief member'
          ),
          'reason', b.reason,
          'blocked_at', b.created_at
        ) order by b.created_at desc
      )
      from public.blocked_users as b
      join public.profiles as p on p.id = b.blocked_id
      left join public.customer_profiles as cp on cp.user_id = b.blocked_id
      left join public.repairer_profiles as rp on rp.user_id = b.blocked_id
      where b.blocker_id = caller_id
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.unblock_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  delete from public.blocked_users
  where blocker_id = caller_id and blocked_id = target_user_id;
  if not found then
    raise exception 'Blocked user not found.' using errcode = 'P0002';
  end if;
  insert into public.audit_events (actor_id, action, entity_type, entity_id)
  values (caller_id, 'account.user_unblocked', 'profile', target_user_id);
end;
$$;

revoke update on public.notifications from authenticated;

revoke all on function private.notification_json(public.notifications) from public, anon, authenticated;
revoke all on function private.notification_preferences_json(public.notification_preferences) from public, anon, authenticated;
revoke all on function private.sync_customer_notification_preferences() from public, anon, authenticated;
revoke all on function public.get_notifications(integer, timestamptz) from public, anon;
revoke all on function public.mark_notification_read(uuid) from public, anon;
revoke all on function public.mark_all_notifications_read() from public, anon;
revoke all on function public.get_settings_overview() from public, anon;
revoke all on function public.update_notification_preferences(jsonb) from public, anon;
revoke all on function public.request_data_export() from public, anon;
revoke all on function public.request_account_deletion(text, text) from public, anon;
revoke all on function public.cancel_account_deletion() from public, anon;
revoke all on function public.get_blocked_users() from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;

grant execute on function public.get_notifications(integer, timestamptz) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
grant execute on function public.get_settings_overview() to authenticated;
grant execute on function public.update_notification_preferences(jsonb) to authenticated;
grant execute on function public.request_data_export() to authenticated;
grant execute on function public.request_account_deletion(text, text) to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.get_blocked_users() to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;

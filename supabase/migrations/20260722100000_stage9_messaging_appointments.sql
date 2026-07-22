-- FixBrief Stage 9: participant-safe messaging, realtime conversation reads,
-- appointment negotiation, and conversation-scoped trust controls.

alter table public.appointments
  alter column job_id drop not null,
  add column conversation_id uuid references public.conversations (id) on delete cascade;

update public.appointments as appointment
set conversation_id = conversation.id
from public.jobs as job
join public.conversations as conversation
  on conversation.request_id = job.request_id
 and conversation.repairer_id = job.repairer_id
where appointment.job_id = job.id
  and appointment.conversation_id is null;

alter table public.appointments
  alter column conversation_id set not null,
  add constraint appointments_job_or_inspection_scope check (
    job_id is not null or kind = 'inspection'
  );

create index appointments_conversation_idx
  on public.appointments (conversation_id, starts_at desc)
  where deleted_at is null;

create or replace function private.can_access_appointment(
  target_appointment_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.appointments as appointment
    where appointment.id = target_appointment_id
      and appointment.deleted_at is null
      and private.can_access_conversation(appointment.conversation_id, viewer_id)
  )
$$;

revoke all on function private.can_access_appointment(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.can_access_private_location(
  target_request_id uuid,
  viewer_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.repair_requests as request
    where request.id = target_request_id
      and request.customer_id = viewer_id
  ) or exists (
    select 1
    from public.jobs as job
    where job.request_id = target_request_id
      and job.repairer_id = viewer_id
      and job.deleted_at is null
  ) or exists (
    select 1
    from public.appointments as appointment
    join public.conversations as conversation
      on conversation.id = appointment.conversation_id
    where appointment.request_id = target_request_id
      and conversation.repairer_id = viewer_id
      and appointment.status in ('confirmed', 'completed')
      and appointment.location_released
      and appointment.deleted_at is null
      and conversation.deleted_at is null
  )
$$;

-- Stage 9 mutations use the guarded RPCs below. Realtime clients retain select.
revoke insert, delete on public.appointments from authenticated;
revoke update on public.appointments from authenticated;
revoke insert on public.messages from authenticated;
revoke update on public.messages from authenticated;

drop policy if exists appointments_read_parties on public.appointments;
drop policy if exists appointments_insert_participant on public.appointments;
drop policy if exists appointments_update_participant on public.appointments;
drop policy if exists appointments_delete_proposer on public.appointments;

create policy appointments_read_parties on public.appointments
for select to authenticated
using (
  deleted_at is null
  and private.can_access_conversation(conversation_id, (select auth.uid()))
);

create or replace function public.get_conversations()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  result jsonb;
begin
  if caller_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.sort_at desc), '[]'::jsonb)
  into result
  from (
    select
      conversation.id,
      conversation.request_id,
      conversation.job_id,
      request.item_name,
      request.approximate_area,
      case
        when conversation.customer_id = caller_id then conversation.repairer_id
        else conversation.customer_id
      end as counterpart_id,
      case
        when conversation.customer_id = caller_id then
          coalesce(repairer.business_name, repairer.full_name, counterpart.display_name, 'Repair professional')
        else coalesce(customer.full_name, counterpart.display_name, 'Customer')
      end as counterpart_name,
      case
        when conversation.customer_id = caller_id then 'repairer'
        else 'customer'
      end as counterpart_role,
      conversation.status,
      latest.body as last_message,
      latest.message_type::text as last_message_type,
      latest.sender_id = caller_id as last_message_is_mine,
      latest.sent_at as last_message_at,
      coalesce(unread.total, 0)::integer as unread_count,
      private.users_are_blocked(conversation.customer_id, conversation.repairer_id) as is_blocked,
      coalesce(latest.sent_at, conversation.created_at) as sort_at
    from public.conversations as conversation
    join public.repair_requests as request on request.id = conversation.request_id
    join public.conversation_participants as participant
      on participant.conversation_id = conversation.id
     and participant.participant_id = caller_id
     and participant.left_at is null
    left join public.profiles as counterpart
      on counterpart.id = case
        when conversation.customer_id = caller_id then conversation.repairer_id
        else conversation.customer_id
      end
    left join public.repairer_profiles as repairer
      on repairer.user_id = conversation.repairer_id
    left join public.customer_profiles as customer
      on customer.user_id = conversation.customer_id
    left join lateral (
      select message.body, message.message_type, message.sender_id, message.sent_at
      from public.messages as message
      where message.conversation_id = conversation.id
        and message.deleted_at is null
      order by message.sent_at desc, message.id desc
      limit 1
    ) as latest on true
    left join lateral (
      select count(*) as total
      from public.messages as message
      where message.conversation_id = conversation.id
        and message.sender_id <> caller_id
        and message.deleted_at is null
        and message.sent_at > coalesce(participant.last_read_at, participant.joined_at)
    ) as unread on true
    where conversation.deleted_at is null
  ) as row_data;

  return result;
end;
$$;

create or replace function public.get_conversation_messages(
  target_conversation_id uuid,
  before_sent_at timestamptz default null,
  page_size integer default 80
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  result jsonb;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.sent_at), '[]'::jsonb)
  into result
  from (
    select
      message.id,
      message.conversation_id,
      message.sender_id,
      message.sender_id = caller_id as is_mine,
      message.message_type::text,
      message.body,
      message.attachment_bucket,
      message.attachment_path,
      message.attachment_name,
      message.attachment_mime_type,
      message.attachment_size,
      message.related_quote_id,
      message.related_job_id,
      message.related_appointment_id,
      message.sent_at,
      message.edited_at,
      message.deleted_at
    from public.messages as message
    where message.conversation_id = target_conversation_id
      and (before_sent_at is null or message.sent_at < before_sent_at)
    order by message.sent_at desc, message.id desc
    limit least(greatest(page_size, 1), 100)
  ) as row_data;

  return result;
end;
$$;

create or replace function public.get_conversation_appointments(
  target_conversation_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  result jsonb;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.starts_at desc), '[]'::jsonb)
  into result
  from (
    select
      appointment.id,
      appointment.conversation_id,
      appointment.job_id,
      appointment.request_id,
      appointment.proposed_by,
      appointment.proposed_by = caller_id as proposed_by_me,
      appointment.kind::text,
      appointment.status::text,
      appointment.starts_at,
      appointment.ends_at,
      appointment.timezone,
      case when appointment.location_released then appointment.location_address end as location_address,
      appointment.location_released,
      appointment.response_message,
      appointment.responded_at,
      appointment.created_at
    from public.appointments as appointment
    where appointment.conversation_id = target_conversation_id
      and appointment.deleted_at is null
  ) as row_data;

  return result;
end;
$$;

create or replace function public.mark_conversation_read(
  target_conversation_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null
    or not private.can_access_conversation(target_conversation_id, auth.uid()) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;

  update public.conversation_participants
  set last_read_at = now(), updated_at = now()
  where conversation_id = target_conversation_id
    and participant_id = auth.uid()
    and left_at is null;

  update public.conversations
  set updated_at = now()
  where id = target_conversation_id;
end;
$$;

create or replace function public.send_conversation_message(
  target_conversation_id uuid,
  client_message_id uuid,
  message_kind text default 'text',
  message_body text default null,
  target_attachment_path text default null,
  target_attachment_name text default null,
  target_attachment_mime_type text default null,
  target_attachment_size bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  inserted_message public.messages%rowtype;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;
  if message_kind not in ('text', 'image', 'document', 'repair_evidence') then
    raise exception 'Unsupported message type.' using errcode = '22023';
  end if;
  if message_body is not null and char_length(trim(message_body)) > 10000 then
    raise exception 'Message is too long.' using errcode = '22023';
  end if;
  if message_kind = 'text' and coalesce(char_length(trim(message_body)), 0) = 0 then
    raise exception 'A text message cannot be empty.' using errcode = '22023';
  end if;
  if target_attachment_path is not null and (
    target_attachment_path not like caller_id::text || '/' || target_conversation_id::text || '/%'
    or target_attachment_size is null
    or target_attachment_size not between 1 and 26214400
    or coalesce(char_length(target_attachment_name), 0) not between 1 and 255
    or coalesce(char_length(target_attachment_mime_type), 0) not between 1 and 200
  ) then
    raise exception 'Attachment metadata is invalid.' using errcode = '22023';
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    client_message_id,
    message_type,
    body,
    attachment_bucket,
    attachment_path,
    attachment_name,
    attachment_mime_type,
    attachment_size
  ) values (
    target_conversation_id,
    caller_id,
    send_conversation_message.client_message_id,
    message_kind::public.message_type,
    nullif(trim(message_body), ''),
    case when target_attachment_path is null then null else 'message-attachments' end,
    target_attachment_path,
    target_attachment_name,
    target_attachment_mime_type,
    target_attachment_size
  )
  on conflict (sender_id, client_message_id) do update
    set client_message_id = excluded.client_message_id
  returning * into inserted_message;

  return to_jsonb(inserted_message) || jsonb_build_object('is_mine', true);
end;
$$;

create or replace function public.propose_appointment(
  target_conversation_id uuid,
  appointment_kind text,
  appointment_starts_at timestamptz,
  appointment_ends_at timestamptz,
  timezone_name text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  selected_conversation public.conversations%rowtype;
  inserted_appointment public.appointments%rowtype;
  recipient_id uuid;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;
  if appointment_kind not in ('inspection', 'repair', 'collection') then
    raise exception 'Unsupported appointment type.' using errcode = '22023';
  end if;
  if appointment_starts_at <= now()
    or appointment_ends_at <= appointment_starts_at
    or appointment_ends_at > appointment_starts_at + interval '14 days' then
    raise exception 'Appointment time range is invalid.' using errcode = '22023';
  end if;
  if char_length(timezone_name) not between 1 and 100 then
    raise exception 'Timezone is invalid.' using errcode = '22023';
  end if;

  select * into selected_conversation
  from public.conversations
  where id = target_conversation_id and deleted_at is null;

  if selected_conversation.job_id is null and appointment_kind <> 'inspection' then
    raise exception 'Only an inspection can be arranged before quote acceptance.' using errcode = '22023';
  end if;

  insert into public.appointments (
    conversation_id,
    job_id,
    request_id,
    proposed_by,
    kind,
    starts_at,
    ends_at,
    timezone
  ) values (
    selected_conversation.id,
    selected_conversation.job_id,
    selected_conversation.request_id,
    caller_id,
    appointment_kind::public.appointment_kind,
    appointment_starts_at,
    appointment_ends_at,
    timezone_name
  ) returning * into inserted_appointment;

  insert into public.messages (
    conversation_id,
    sender_id,
    client_message_id,
    message_type,
    body,
    related_appointment_id
  ) values (
    target_conversation_id,
    caller_id,
    gen_random_uuid(),
    'appointment',
    'Proposed an appointment.',
    inserted_appointment.id
  );

  recipient_id := case
    when selected_conversation.customer_id = caller_id then selected_conversation.repairer_id
    else selected_conversation.customer_id
  end;
  insert into public.notifications (
    recipient_id, notification_type, title, body,
    related_entity_type, related_entity_id, deep_link, dedupe_key
  ) values (
    recipient_id, 'inspection_proposed', 'Appointment proposed',
    'Open the conversation to review the proposed time.',
    'appointment', inserted_appointment.id,
    '/messages/' || target_conversation_id::text,
    'appointment-proposed:' || inserted_appointment.id::text
  ) on conflict (recipient_id, dedupe_key) where dedupe_key is not null and deleted_at is null
    do nothing;

  return to_jsonb(inserted_appointment) || jsonb_build_object('proposed_by_me', true);
end;
$$;

create or replace function public.respond_to_appointment(
  target_appointment_id uuid,
  response_status text,
  response_message text default null,
  release_customer_location boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  selected_appointment public.appointments%rowtype;
  selected_conversation public.conversations%rowtype;
  updated_appointment public.appointments%rowtype;
  recipient_id uuid;
begin
  if caller_id is null
    or not private.can_access_appointment(target_appointment_id, caller_id) then
    raise exception 'Appointment access denied.' using errcode = '42501';
  end if;
  if response_status not in ('confirmed', 'declined', 'cancelled') then
    raise exception 'Unsupported appointment response.' using errcode = '22023';
  end if;
  if response_message is not null and char_length(response_message) > 2000 then
    raise exception 'Appointment response is too long.' using errcode = '22023';
  end if;

  select * into selected_appointment
  from public.appointments
  where id = target_appointment_id and deleted_at is null
  for update;
  select * into selected_conversation
  from public.conversations
  where id = selected_appointment.conversation_id;

  if response_status in ('confirmed', 'declined')
    and selected_appointment.proposed_by = caller_id then
    raise exception 'The other participant must respond to this proposal.' using errcode = '42501';
  end if;
  if selected_appointment.status <> 'proposed' and response_status <> 'cancelled' then
    raise exception 'This appointment has already been answered.' using errcode = '22023';
  end if;
  if release_customer_location and caller_id <> selected_conversation.customer_id then
    raise exception 'Only the customer can release the exact location.' using errcode = '42501';
  end if;

  update public.appointments as appointment
  set
    status = response_status::public.appointment_status,
    response_message = nullif(trim(respond_to_appointment.response_message), ''),
    responded_at = now(),
    location_released = release_customer_location and response_status = 'confirmed',
    location_address = case
      when release_customer_location and response_status = 'confirmed' then (
        select location.exact_address
        from public.repair_request_private_locations as location
        where location.request_id = selected_appointment.request_id
          and location.customer_id = caller_id
          and location.deleted_at is null
      )
      else appointment.location_address
    end,
    updated_at = now()
  where appointment.id = target_appointment_id
  returning * into updated_appointment;

  insert into public.messages (
    conversation_id, sender_id, client_message_id, message_type, body,
    related_appointment_id
  ) values (
    selected_conversation.id, caller_id, gen_random_uuid(), 'appointment',
    'Appointment ' || response_status || '.', updated_appointment.id
  );

  recipient_id := case
    when selected_conversation.customer_id = caller_id then selected_conversation.repairer_id
    else selected_conversation.customer_id
  end;
  insert into public.notifications (
    recipient_id, notification_type, title, body,
    related_entity_type, related_entity_id, deep_link, dedupe_key
  ) values (
    recipient_id,
    case when response_status = 'confirmed'
      then 'appointment_confirmed'::public.notification_type
      else 'inspection_proposed'::public.notification_type end,
    'Appointment ' || response_status,
    'Open the conversation to view the appointment update.',
    'appointment', updated_appointment.id,
    '/messages/' || selected_conversation.id::text,
    'appointment-response:' || updated_appointment.id::text || ':' || response_status
  ) on conflict (recipient_id, dedupe_key) where dedupe_key is not null and deleted_at is null
    do nothing;

  return to_jsonb(updated_appointment)
    || jsonb_build_object('proposed_by_me', updated_appointment.proposed_by = caller_id);
end;
$$;

create or replace function public.set_conversation_blocked(
  target_conversation_id uuid,
  should_block boolean,
  block_reason text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  other_user_id uuid;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;
  if block_reason is not null and char_length(block_reason) > 1000 then
    raise exception 'Block reason is too long.' using errcode = '22023';
  end if;

  select participant_id into other_user_id
  from public.conversation_participants
  where conversation_id = target_conversation_id
    and participant_id <> caller_id
    and left_at is null
  limit 1;

  if should_block then
    insert into public.blocked_users (blocker_id, blocked_id, reason)
    values (caller_id, other_user_id, nullif(trim(block_reason), ''))
    on conflict (blocker_id, blocked_id) do update
      set reason = excluded.reason;
    update public.conversations
    set status = 'closed', closed_at = now(), updated_at = now()
    where id = target_conversation_id;
  else
    delete from public.blocked_users
    where blocker_id = caller_id and blocked_id = other_user_id;
    if not private.users_are_blocked(caller_id, other_user_id) then
      update public.conversations
      set status = 'active', closed_at = null, updated_at = now()
      where id = target_conversation_id;
    end if;
  end if;
end;
$$;

create or replace function public.report_conversation_user(
  target_conversation_id uuid,
  report_reason text,
  report_details text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  caller_id uuid := auth.uid();
  other_user_id uuid;
  new_report_id uuid;
begin
  if caller_id is null
    or not private.can_access_conversation(target_conversation_id, caller_id) then
    raise exception 'Conversation access denied.' using errcode = '42501';
  end if;
  if report_reason not in (
    'spam', 'harassment', 'fraud', 'unsafe_content',
    'inappropriate_content', 'identity_concern', 'other'
  ) then
    raise exception 'Unsupported report reason.' using errcode = '22023';
  end if;
  if report_details is not null and char_length(report_details) > 5000 then
    raise exception 'Report details are too long.' using errcode = '22023';
  end if;

  select participant_id into other_user_id
  from public.conversation_participants
  where conversation_id = target_conversation_id
    and participant_id <> caller_id
    and left_at is null
  limit 1;

  insert into public.reports (
    reporter_id, subject_user_id, related_entity_type, related_entity_id,
    reason, details
  ) values (
    caller_id, other_user_id, 'conversation', target_conversation_id,
    report_reason::public.report_reason, nullif(trim(report_details), '')
  ) returning id into new_report_id;

  return new_report_id;
end;
$$;

revoke all on function public.get_conversations() from public, anon;
revoke all on function public.get_conversation_messages(uuid, timestamptz, integer) from public, anon;
revoke all on function public.get_conversation_appointments(uuid) from public, anon;
revoke all on function public.mark_conversation_read(uuid) from public, anon;
revoke all on function public.send_conversation_message(uuid, uuid, text, text, text, text, text, bigint) from public, anon;
revoke all on function public.propose_appointment(uuid, text, timestamptz, timestamptz, text) from public, anon;
revoke all on function public.respond_to_appointment(uuid, text, text, boolean) from public, anon;
revoke all on function public.set_conversation_blocked(uuid, boolean, text) from public, anon;
revoke all on function public.report_conversation_user(uuid, text, text) from public, anon;

grant execute on function public.get_conversations() to authenticated;
grant execute on function public.get_conversation_messages(uuid, timestamptz, integer) to authenticated;
grant execute on function public.get_conversation_appointments(uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.send_conversation_message(uuid, uuid, text, text, text, text, text, bigint) to authenticated;
grant execute on function public.propose_appointment(uuid, text, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.respond_to_appointment(uuid, text, text, boolean) to authenticated;
grant execute on function public.set_conversation_blocked(uuid, boolean, text) to authenticated;
grant execute on function public.report_conversation_user(uuid, text, text) to authenticated;

-- Typing indicators use private Broadcast channels. The topic UUID must map to
-- a conversation in which the authenticated user is an active participant.
drop policy if exists fixbrief_conversation_broadcast_read on realtime.messages;
create policy fixbrief_conversation_broadcast_read
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and (select realtime.topic())
    ~ '^conversation-typing:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and private.can_access_conversation(
    split_part((select realtime.topic()), ':', 2)::uuid,
    (select auth.uid())
  )
);

drop policy if exists fixbrief_conversation_broadcast_write on realtime.messages;
create policy fixbrief_conversation_broadcast_write
on realtime.messages for insert to authenticated
with check (
  realtime.messages.extension = 'broadcast'
  and (select realtime.topic())
    ~ '^conversation-typing:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and private.can_access_conversation(
    split_part((select realtime.topic()), ':', 2)::uuid,
    (select auth.uid())
  )
);

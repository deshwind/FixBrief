-- FixBrief Stage 4: private storage buckets and object policies. Bucket limits
-- are a first line of defence; clients and trusted backends must still inspect
-- file signatures and quarantine unsafe content.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values
  (
    'profile-images',
    'profile-images',
    false,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'business-logos',
    'business-logos',
    false,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'repair-request-images',
    'repair-request-images',
    false,
    12582912,
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'repair-request-videos',
    'repair-request-videos',
    false,
    104857600,
    array['video/mp4', 'video/quicktime']
  ),
  (
    'repair-request-audio',
    'repair-request-audio',
    false,
    26214400,
    array['audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/x-wav']
  ),
  (
    'message-attachments',
    'message-attachments',
    false,
    26214400,
    array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
      'text/plain',
      'audio/mp4',
      'audio/mpeg'
    ]
  ),
  (
    'certifications',
    'certifications',
    false,
    15728640,
    array['application/pdf', 'image/jpeg', 'image/png']
  ),
  (
    'review-media',
    'review-media',
    false,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.storage_owner_id(object_name text)
returns uuid
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when split_part(object_name, '/', 1)
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then split_part(object_name, '/', 1)::uuid
    else null
  end
$$;

create or replace function private.storage_related_id(object_name text)
returns uuid
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when split_part(object_name, '/', 2)
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then split_part(object_name, '/', 2)::uuid
    else null
  end
$$;

create or replace function private.can_access_storage_object(
  target_bucket text,
  object_name text,
  viewer_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  owner_user_id uuid := private.storage_owner_id(object_name);
  related_id uuid := private.storage_related_id(object_name);
begin
  if viewer_id is null or owner_user_id is null then
    return false;
  end if;
  if owner_user_id = viewer_id then
    return true;
  end if;

  if target_bucket = 'business-logos' then
    return exists (
      select 1 from public.repairer_profiles as rp
      where rp.user_id = owner_user_id
        and rp.is_marketplace_visible
        and rp.verification_status = 'verified'
        and rp.deleted_at is null
    );
  elsif target_bucket = 'profile-images' then
    return exists (
      select 1 from public.repairer_profiles as rp
      where rp.user_id = owner_user_id
        and rp.is_marketplace_visible
        and rp.verification_status = 'verified'
        and rp.deleted_at is null
    ) or exists (
      select 1 from public.conversations as c
      where c.deleted_at is null
        and (
          (c.customer_id = owner_user_id and c.repairer_id = viewer_id)
          or (c.repairer_id = owner_user_id and c.customer_id = viewer_id)
        )
    );
  elsif target_bucket in (
    'repair-request-images',
    'repair-request-videos',
    'repair-request-audio'
  ) then
    return related_id is not null
      and private.can_access_request_evidence(related_id, viewer_id);
  elsif target_bucket = 'message-attachments' then
    return related_id is not null
      and private.can_access_conversation(related_id, viewer_id);
  elsif target_bucket = 'certifications' then
    return false;
  elsif target_bucket = 'review-media' then
    return related_id is not null and exists (
      select 1 from public.reviews as r
      where r.id = related_id and r.deleted_at is null
    );
  end if;
  return false;
end;
$$;

revoke all on function private.storage_owner_id(text) from public, anon, authenticated;
revoke all on function private.storage_related_id(text) from public, anon, authenticated;
revoke all on function private.can_access_storage_object(text, text, uuid) from public, anon, authenticated;
grant execute on function private.storage_owner_id(text) to authenticated;
grant execute on function private.storage_related_id(text) to authenticated;
grant execute on function private.can_access_storage_object(text, text, uuid) to authenticated;

drop policy if exists fixbrief_private_objects_read on storage.objects;
create policy fixbrief_private_objects_read
  on storage.objects for select
  to authenticated
  using (
    bucket_id in (
      'profile-images',
      'business-logos',
      'repair-request-images',
      'repair-request-videos',
      'repair-request-audio',
      'message-attachments',
      'certifications',
      'review-media'
    )
    and private.can_access_storage_object(bucket_id, name, (select auth.uid()))
  );

drop policy if exists fixbrief_private_objects_insert on storage.objects;
create policy fixbrief_private_objects_insert
  on storage.objects for insert
  to authenticated
  with check (
    private.storage_owner_id(name) = (select auth.uid())
    and (
      bucket_id = 'profile-images'
      or (
        bucket_id in ('business-logos', 'certifications')
        and private.current_user_role() = 'repairer'
      )
      or (
        bucket_id in (
          'repair-request-images',
          'repair-request-videos',
          'repair-request-audio'
        )
        and exists (
          select 1 from public.repair_requests as r
          where r.id = private.storage_related_id(name)
            and r.customer_id = (select auth.uid())
            and r.status = 'draft'
            and r.deleted_at is null
        )
      )
      or (
        bucket_id = 'message-attachments'
        and private.can_access_conversation(
          private.storage_related_id(name),
          (select auth.uid())
        )
      )
      or (
        bucket_id = 'review-media'
        and exists (
          select 1 from public.reviews as r
          where r.id = private.storage_related_id(name)
            and r.author_id = (select auth.uid())
            and r.deleted_at is null
        )
      )
    )
  );

drop policy if exists fixbrief_private_objects_update on storage.objects;
create policy fixbrief_private_objects_update
  on storage.objects for update
  to authenticated
  using (private.storage_owner_id(name) = (select auth.uid()))
  with check (private.storage_owner_id(name) = (select auth.uid()));

drop policy if exists fixbrief_private_objects_delete on storage.objects;
create policy fixbrief_private_objects_delete
  on storage.objects for delete
  to authenticated
  using (private.storage_owner_id(name) = (select auth.uid()));

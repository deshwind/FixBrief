-- FixBrief Stage 5: private document evidence for receipts and warranties.

alter table public.repair_requests
  add column custom_category text;

alter table public.repair_requests
  add constraint repair_requests_custom_category_length check (
    custom_category is null or char_length(custom_category) between 2 and 120
  );

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'repair-request-documents',
  'repair-request-documents',
  false,
  15728640,
  array['application/pdf', 'text/plain']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.repair_request_media
  drop constraint repair_request_media_bucket;

alter table public.repair_request_media
  add constraint repair_request_media_bucket check (
    bucket_name in (
      'repair-request-images',
      'repair-request-videos',
      'repair-request-audio',
      'repair-request-documents'
    )
  );

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
    'repair-request-audio',
    'repair-request-documents'
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
      'repair-request-documents',
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
          'repair-request-audio',
          'repair-request-documents'
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

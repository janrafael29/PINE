-- Idempotent: admin profiles/fields/storage (re-run safe).

drop policy if exists "profiles_select_jwt_admin" on public.profiles;
drop policy if exists "profiles_insert_jwt_admin" on public.profiles;
drop policy if exists "profiles_update_jwt_admin" on public.profiles;
drop policy if exists "profiles_delete_jwt_admin" on public.profiles;

drop policy if exists "fields_insert_jwt_admin" on public.fields;
drop policy if exists "fields_delete_jwt_admin" on public.fields;

drop policy if exists "detections_storage_insert_jwt_admin" on storage.objects;
drop policy if exists "detections_storage_update_jwt_admin" on storage.objects;
drop policy if exists "detections_storage_delete_jwt_admin" on storage.objects;

create policy "profiles_select_jwt_admin" on public.profiles for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "profiles_insert_jwt_admin" on public.profiles for insert
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "profiles_update_jwt_admin" on public.profiles for
update
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  )
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "profiles_delete_jwt_admin" on public.profiles for delete using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
);

create policy "fields_insert_jwt_admin" on public.fields for insert
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "fields_delete_jwt_admin" on public.fields for delete using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
);

create policy "detections_storage_insert_jwt_admin" on storage.objects for insert
with
  check (
    bucket_id = 'detections'
    and coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "detections_storage_update_jwt_admin" on storage.objects for
update
  using (
    bucket_id = 'detections'
    and coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  )
with
  check (
    bucket_id = 'detections'
    and coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "detections_storage_delete_jwt_admin" on storage.objects for delete using (
  bucket_id = 'detections'
  and coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
);

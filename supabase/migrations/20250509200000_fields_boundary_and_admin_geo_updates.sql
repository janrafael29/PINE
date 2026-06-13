-- Field geo-fence stored as JSON array of { "lat", "lng" } (matches app / DatabaseService).
-- Admin JWT (app_metadata.admin) can update boundaries and correct detection coordinates.

alter table public.fields
add column if not exists boundary_json jsonb;

create policy "fields_update_jwt_admin" on public.fields for
update
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  )
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "detections_select_jwt_admin" on public.detections for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "detections_update_jwt_admin" on public.detections for
update
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  )
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

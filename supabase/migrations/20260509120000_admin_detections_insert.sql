-- Allow dashboard admins (JWT app_metadata.admin) to insert detections (e.g. duplicate captures).

drop policy if exists "detections_insert_jwt_admin" on public.detections;

create policy "detections_insert_jwt_admin" on public.detections for insert
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

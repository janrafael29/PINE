-- Allow dashboard-designated admins (JWT app_metadata.admin = true) to read all
-- profiles and fields for the admin web console.
--
-- Set on a user in Supabase Dashboard → Authentication → Users → user →
-- Raw app metadata: { "admin": true }  (merge with existing keys).

create policy "profiles_select_jwt_admin" on public.profiles for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "fields_select_jwt_admin" on public.fields for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

-- DA staff role: read org-wide data like admin, but only write expert advice (not fields/users/detections).

create or replace function public.jwt_is_full_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false);
$$;

create or replace function public.jwt_is_da_staff()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'da')::boolean, false)
    or lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'da';
$$;

create or replace function public.jwt_is_staff()
returns boolean
language sql
stable
as $$
  select public.jwt_is_full_admin() or public.jwt_is_da_staff();
$$;

-- Org-wide read for DA staff (parallel to existing admin select policies).
create policy "profiles_select_jwt_da" on public.profiles for select using (public.jwt_is_da_staff());

create policy "fields_select_jwt_da" on public.fields for select using (public.jwt_is_da_staff());

create policy "detections_select_jwt_da" on public.detections for select using (public.jwt_is_da_staff());

-- Expert advice: DA staff may insert/update their own replies; full admin retains delete.
drop policy if exists "expert_responses_insert_jwt_admin" on public.expert_responses;
drop policy if exists "expert_responses_update_jwt_admin" on public.expert_responses;

create policy "expert_responses_insert_jwt_staff" on public.expert_responses for insert
with check (
  public.jwt_is_staff()
  and author_id = auth.uid()
);

create policy "expert_responses_update_jwt_staff" on public.expert_responses for update
using (
  public.jwt_is_staff()
  and author_id = auth.uid()
)
with check (
  public.jwt_is_staff()
  and author_id = auth.uid()
);

-- Farm insights remain full-admin only; DA may read for analytics.
create policy "farm_insights_select_jwt_da" on public.farm_insights for select using (public.jwt_is_da_staff());

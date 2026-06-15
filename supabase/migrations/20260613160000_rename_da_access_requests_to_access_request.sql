-- Rename da_access_requests → access_request (panel naming).

alter table if exists public.da_access_requests rename to access_request;

alter index if exists public.da_access_requests_user_id_idx
  rename to access_request_user_id_idx;

alter index if exists public.da_access_requests_status_created_idx
  rename to access_request_status_created_idx;

alter index if exists public.da_access_requests_one_pending_per_user
  rename to access_request_one_pending_per_user;

alter policy "da_access_requests_select_own" on public.access_request
  rename to "access_request_select_own";

alter policy "da_access_requests_select_admin" on public.access_request
  rename to "access_request_select_admin";

drop policy if exists "da_access_requests_insert_own" on public.access_request;

create policy "access_request_insert_own" on public.access_request
  for insert
  with check (
    auth.uid() = user_id
    and status = 'pending'
    and not public.jwt_is_staff()
    and not exists (
      select 1
      from public.access_request r
      where r.user_id = auth.uid()
        and r.status = 'pending'
    )
  );

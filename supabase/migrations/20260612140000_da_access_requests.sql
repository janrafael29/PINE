-- DA access approval workflow: farmers request, full admins approve via edge function.

create table if not exists public.da_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  note text,
  reviewer_id uuid references auth.users (id) on delete set null,
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists da_access_requests_user_id_idx
  on public.da_access_requests (user_id);

create index if not exists da_access_requests_status_created_idx
  on public.da_access_requests (status, created_at desc);

create unique index if not exists da_access_requests_one_pending_per_user
  on public.da_access_requests (user_id)
  where status = 'pending';

alter table public.da_access_requests enable row level security;

create policy "da_access_requests_select_own" on public.da_access_requests for select
using (auth.uid() = user_id);

create policy "da_access_requests_select_admin" on public.da_access_requests for select
using (public.jwt_is_full_admin());

create policy "da_access_requests_insert_own" on public.da_access_requests for insert
with check (
  auth.uid() = user_id
  and status = 'pending'
  and not public.jwt_is_staff()
  and not exists (
    select 1
    from public.da_access_requests r
    where r.user_id = auth.uid()
      and r.status = 'pending'
  )
);

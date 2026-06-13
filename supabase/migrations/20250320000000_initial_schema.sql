-- PINE: profiles, fields, detections + RLS (Supabase Postgres)
-- Apply in Supabase SQL Editor or via `supabase db push`.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text,
  email text,
  display_name text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fields (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  address text not null default '',
  preview_image_path text,
  image_count integer not null default 0,
  last_detection timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fields_user_id_idx on public.fields (user_id);

create table if not exists public.detections (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references auth.users (id) on delete cascade,
  field_id uuid references public.fields (id) on delete set null,
  image_url text,
  confidence double precision,
  count integer not null default 0,
  has_mealybugs boolean not null default false,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create index if not exists detections_user_id_idx on public.detections (user_id);
create index if not exists detections_field_id_idx on public.detections (field_id);
create index if not exists detections_created_at_idx on public.detections (created_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.fields enable row level security;
alter table public.detections enable row level security;

-- profiles: one row per auth user
create policy "profiles_select_own" on public.profiles for
select
  using (auth.uid () = id);

create policy "profiles_insert_own" on public.profiles for insert
with
  check (auth.uid () = id);

create policy "profiles_update_own" on public.profiles for
update using (auth.uid () = id)
with
  check (auth.uid () = id);

create policy "profiles_delete_own" on public.profiles for delete using (auth.uid () = id);

-- fields
create policy "fields_select_own" on public.fields for
select
  using (auth.uid () = user_id);

create policy "fields_insert_own" on public.fields for insert
with
  check (auth.uid () = user_id);

create policy "fields_update_own" on public.fields for
update using (auth.uid () = user_id)
with
  check (auth.uid () = user_id);

create policy "fields_delete_own" on public.fields for delete using (auth.uid () = user_id);

-- detections: owner only
create policy "detections_select_own" on public.detections for
select
  using (auth.uid () = user_id);

create policy "detections_insert_own" on public.detections for insert
with
  check (auth.uid () = user_id);

create policy "detections_update_own" on public.detections for
update using (auth.uid () = user_id)
with
  check (auth.uid () = user_id);

create policy "detections_delete_own" on public.detections for delete using (auth.uid () = user_id);

-- ---------------------------------------------------------------------------
-- Storage: bucket `detections` (create bucket in Dashboard if SQL not allowed)
-- ---------------------------------------------------------------------------
-- Run in SQL (requires storage extension):
insert into
  storage.buckets (id, name, public)
values
  ('detections', 'detections', true),
  ('avatars', 'avatars', true) on conflict (id) do
update
set
  public = excluded.public;

-- Authenticated users can read/write only under folder named with their user id.
create policy "detections_storage_select_own" on storage.objects for
select
  using (
    bucket_id = 'detections'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "detections_storage_insert_own" on storage.objects for insert
with
  check (
    bucket_id = 'detections'
    and auth.role () = 'authenticated'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "detections_storage_update_own" on storage.objects for
update using (
  bucket_id = 'detections'
  and (storage.foldername (name)) [1] = auth.uid ()::text
)
with
  check (
    bucket_id = 'detections'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "detections_storage_delete_own" on storage.objects for delete using (
  bucket_id = 'detections'
  and (storage.foldername (name)) [1] = auth.uid ()::text
);

-- Avatars: same path pattern userId/filename
create policy "avatars_storage_select_own" on storage.objects for
select
  using (
    bucket_id = 'avatars'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "avatars_storage_insert_own" on storage.objects for insert
with
  check (
    bucket_id = 'avatars'
    and auth.role () = 'authenticated'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "avatars_storage_update_own" on storage.objects for
update using (
  bucket_id = 'avatars'
  and (storage.foldername (name)) [1] = auth.uid ()::text
)
with
  check (
    bucket_id = 'avatars'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy "avatars_storage_delete_own" on storage.objects for delete using (
  bucket_id = 'avatars'
  and (storage.foldername (name)) [1] = auth.uid ()::text
);

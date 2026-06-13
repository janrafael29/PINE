-- DA/OMAG expert replies per detection report + optional farm-level insights.

create table if not exists public.expert_responses (
  id uuid primary key default gen_random_uuid(),
  detection_id uuid not null references public.detections (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  strategy_text text not null,
  action_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (detection_id)
);

create index if not exists expert_responses_detection_id_idx
  on public.expert_responses (detection_id);

create table if not exists public.farm_insights (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  insight_text text not null,
  created_at timestamptz not null default now()
);

create index if not exists farm_insights_field_id_idx on public.farm_insights (field_id);

alter table public.expert_responses enable row level security;
alter table public.farm_insights enable row level security;

-- Farmers read replies on their own detections.
create policy "expert_responses_select_own_detection" on public.expert_responses for
select
  using (
    exists (
      select 1
      from public.detections d
      where d.id = expert_responses.detection_id
        and d.user_id = auth.uid ()
    )
  );

-- Admin JWT: full access.
create policy "expert_responses_select_jwt_admin" on public.expert_responses for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "expert_responses_insert_jwt_admin" on public.expert_responses for insert
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
    and author_id = auth.uid ()
  );

create policy "expert_responses_update_jwt_admin" on public.expert_responses for
update using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
)
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "expert_responses_delete_jwt_admin" on public.expert_responses for delete using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
);

-- Farm insights: farmers read on own fields; admin write.
create policy "farm_insights_select_own_field" on public.farm_insights for
select
  using (
    exists (
      select 1
      from public.fields f
      where f.id = farm_insights.field_id
        and f.user_id = auth.uid ()
    )
  );

create policy "farm_insights_select_jwt_admin" on public.farm_insights for
select
  using (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "farm_insights_insert_jwt_admin" on public.farm_insights for insert
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
    and author_id = auth.uid ()
  );

create policy "farm_insights_update_jwt_admin" on public.farm_insights for
update using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
)
with
  check (
    coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
  );

create policy "farm_insights_delete_jwt_admin" on public.farm_insights for delete using (
  coalesce((auth.jwt() -> 'app_metadata' ->> 'admin')::boolean, false) = true
);

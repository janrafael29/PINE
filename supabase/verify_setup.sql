-- PINE — run this in Supabase SQL Editor to confirm DB + storage match the app.
-- Expect every row to show status = OK. Anything else: run migrations first.

-- ---------------------------------------------------------------------------
-- 1) Core tables
-- ---------------------------------------------------------------------------
select
  'public.profiles' as object,
  case
    when exists (
      select 1
      from information_schema.tables
      where table_schema = 'public'
        and table_name = 'profiles'
    ) then 'OK'
    else 'FAIL: run supabase/migrations/*_initial_schema.sql'
  end as status
union all
select
  'public.fields',
  case
    when exists (
      select 1
      from information_schema.tables
      where table_schema = 'public'
        and table_name = 'fields'
    ) then 'OK'
    else 'FAIL'
  end
union all
select
  'public.detections',
  case
    when exists (
      select 1
      from information_schema.tables
      where table_schema = 'public'
        and table_name = 'detections'
    ) then 'OK'
    else 'FAIL'
  end;

-- ---------------------------------------------------------------------------
-- 2) RLS enabled
-- ---------------------------------------------------------------------------
select
  c.relname::text as table_name,
  case when c.relrowsecurity then 'OK (RLS on)' else 'FAIL: RLS not enabled' end as status
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('profiles', 'fields', 'detections')
  and c.relkind = 'r'
order by 1;

-- ---------------------------------------------------------------------------
-- 3) Policy counts (expect at least 4 per table for CRUD-style policies)
-- ---------------------------------------------------------------------------
select
  tablename,
  count(*)::int as policy_count
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'fields', 'detections')
group by tablename
order by tablename;

-- ---------------------------------------------------------------------------
-- 4) Storage buckets
-- ---------------------------------------------------------------------------
select
  id,
  name,
  public as is_public,
  case when id in ('detections', 'avatars') then 'OK' else 'CHECK' end as note
from storage.buckets
where id in ('detections', 'avatars')
order by id;

-- ---------------------------------------------------------------------------
-- 5) Storage policies (objects on storage.objects)
-- ---------------------------------------------------------------------------
select
  policyname,
  count(*) over () as total_policies_in_result
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname like any (array['%detections%', '%avatars%'])
order by policyname;

-- ---------------------------------------------------------------------------
-- 6) Realtime (required for Flutter .stream() on these tables)
-- If FAIL: run migrations/20250321000001_enable_realtime.sql
-- or Dashboard → Database → Publications → supabase_realtime.
-- ---------------------------------------------------------------------------
select
  t.tablename::text as table_name,
  case
    when pt.tablename is not null then 'OK (in supabase_realtime)'
    else 'FAIL: run enable_realtime migration'
  end as realtime_status
from (
  values
    ('profiles'),
    ('fields'),
    ('detections')
) as t (tablename)
left join pg_publication_tables pt
  on pt.pubname = 'supabase_realtime'
  and pt.schemaname = 'public'
  and pt.tablename::text = t.tablename
order by 1;

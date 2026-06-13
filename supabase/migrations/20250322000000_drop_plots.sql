-- PINE: remove legacy `plots` (field sub-plots). Safe if already removed.
-- Use when upgrading a database that was created from an older `initial_schema`
-- that included `plots`, `detections.plot_id`, or `fields.plot_count`.

do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'plots'
  ) then
    execute 'alter publication supabase_realtime drop table public.plots';
  end if;
end $$;

drop index if exists public.detections_plot_id_idx;

alter table public.detections
  drop column if exists plot_id;

drop table if exists public.plots;

alter table public.fields
  drop column if exists plot_count;

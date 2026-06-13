-- Realtime: required for Supabase Flutter `.stream(primaryKey: ['id'])` on these tables.
-- Safe to run once; if a table is already in the publication, you may see an error — ignore or comment that line.

alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.fields;
alter publication supabase_realtime add table public.detections;

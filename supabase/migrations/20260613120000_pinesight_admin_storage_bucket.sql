-- Public bucket for hosting PineSight Admin static site (HTML/JS/CSS).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pinesight-admin',
  'pinesight-admin',
  true,
  5242880,
  array[
    'text/html',
    'text/css',
    'application/javascript',
    'application/json',
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/svg+xml'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "pinesight_admin_public_read" on storage.objects;
create policy "pinesight_admin_public_read"
  on storage.objects for select
  using (bucket_id = 'pinesight-admin');

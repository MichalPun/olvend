insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'daily-instructions',
  'daily-instructions',
  true,
  10485760,
  array['application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public read daily instruction PDFs" on storage.objects;
create policy "Public read daily instruction PDFs"
on storage.objects
for select
to public
using (bucket_id = 'daily-instructions');

drop policy if exists "Authenticated upload daily instruction PDFs" on storage.objects;
create policy "Authenticated upload daily instruction PDFs"
on storage.objects
for insert
to authenticated, anon
with check (bucket_id = 'daily-instructions');

drop policy if exists "Authenticated update daily instruction PDFs" on storage.objects;
create policy "Authenticated update daily instruction PDFs"
on storage.objects
for update
to authenticated, anon
using (bucket_id = 'daily-instructions')
with check (bucket_id = 'daily-instructions');

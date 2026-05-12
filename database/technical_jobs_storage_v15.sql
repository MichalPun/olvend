insert into storage.buckets (id, name, public)
values ('technical-job-files', 'technical-job-files', true)
on conflict (id) do nothing;

drop policy if exists "Public read technical job files"
on storage.objects;

create policy "Public read technical job files"
on storage.objects
for select
to authenticated, anon
using (bucket_id = 'technical-job-files');

drop policy if exists "Allow insert technical job files"
on storage.objects;

create policy "Allow insert technical job files"
on storage.objects
for insert
to authenticated, anon
with check (bucket_id = 'technical-job-files');

drop policy if exists "Allow update technical job files"
on storage.objects;

create policy "Allow update technical job files"
on storage.objects
for update
to authenticated, anon
using (bucket_id = 'technical-job-files')
with check (bucket_id = 'technical-job-files');

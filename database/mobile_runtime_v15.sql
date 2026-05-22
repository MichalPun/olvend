alter table public.vehicle_operation_logs
  add column if not exists fuel_odometer_km integer,
  add column if not exists fuel_receipt_url text;

alter table public.service_requests
  add column if not exists service_result text,
  add column if not exists work_performed text,
  add column if not exists used_parts text,
  add column if not exists next_recommendation text,
  add column if not exists internal_service_note text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'shift-documents',
  'shift-documents',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public read shift documents" on storage.objects;
create policy "Public read shift documents"
on storage.objects
for select
to public
using (bucket_id = 'shift-documents');

drop policy if exists "Authenticated upload shift documents" on storage.objects;
create policy "Authenticated upload shift documents"
on storage.objects
for insert
to authenticated, anon
with check (bucket_id = 'shift-documents');

drop policy if exists "Authenticated update shift documents" on storage.objects;
create policy "Authenticated update shift documents"
on storage.objects
for update
to authenticated, anon
using (bucket_id = 'shift-documents')
with check (bucket_id = 'shift-documents');

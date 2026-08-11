begin;

drop policy if exists "Private signature images read" on storage.objects;
create policy "Private signature images read" on storage.objects for select to authenticated
using (
  bucket_id = 'mail-signature-assets'
  and public.is_mail_owner(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "Private signature images insert" on storage.objects;
create policy "Private signature images insert" on storage.objects for insert to authenticated
with check (
  bucket_id = 'mail-signature-assets'
  and public.is_mail_owner(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "Private signature images update" on storage.objects;
create policy "Private signature images update" on storage.objects for update to authenticated
using (
  bucket_id = 'mail-signature-assets'
  and public.is_mail_owner(((storage.foldername(name))[1])::uuid)
) with check (
  bucket_id = 'mail-signature-assets'
  and public.is_mail_owner(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "Private signature images delete" on storage.objects;
create policy "Private signature images delete" on storage.objects for delete to authenticated
using (
  bucket_id = 'mail-signature-assets'
  and public.is_mail_owner(((storage.foldername(name))[1])::uuid)
);

commit;

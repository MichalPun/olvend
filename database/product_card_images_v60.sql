begin;

alter table public.products
  add column if not exists image_path text,
  add column if not exists image_updated_at timestamp with time zone;

comment on column public.products.image_path is
  'Cesta fotografie produktu. Prefix static: odkazuje na soubor v aplikaci, ostatni cesty na bucket product-images.';

comment on column public.products.image_updated_at is
  'Cas posledni zmeny nebo odstraneni fotografie produktu.';

create or replace function public.guard_product_image_change_v60()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_changed boolean;
begin
  v_changed := case
    when tg_op = 'INSERT' then new.image_path is not null
    else new.image_path is distinct from old.image_path
  end;
  if v_changed
     and current_setting('role', true) in ('anon', 'authenticated')
     and not public.has_manager_access() then
    raise exception 'Fotografii produktu může měnit pouze vedení.' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_product_image_change_v60() from public;

drop trigger if exists trg_guard_product_image_change_v60 on public.products;
create trigger trg_guard_product_image_change_v60
before insert or update of image_path on public.products
for each row execute function public.guard_product_image_change_v60();

-- Dosavadni dve fotografie se stanou soucasti kmenove karty. Po prvnim
-- nahrani z aplikace se hodnota nahradi cestou v ulozisti.
update public.products
set image_path = case trim(sku)
  when '44' then 'static:./assets/product-images/44.jpg'
  when '47' then 'static:./assets/product-images/47.jpg'
  when '48' then 'static:./assets/product-images/48.jpg'
  when '201' then 'static:./assets/product-images/201.jpg'
  else image_path
end,
image_updated_at = coalesce(image_updated_at, now())
where trim(sku) in ('44', '47', '48', '201')
  and image_path is null;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public read product images" on storage.objects;
drop policy if exists "Active employees read product images" on storage.objects;
create policy "Active employees read product images"
on storage.objects
for select
to authenticated
using (bucket_id = 'product-images' and public.current_employee_id() is not null);

drop policy if exists "Authenticated upload product images" on storage.objects;
create policy "Authenticated upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = 'products'
  and public.has_manager_access()
);

drop policy if exists "Authenticated replace product images" on storage.objects;
create policy "Authenticated replace product images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = 'products'
  and public.has_manager_access()
)
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = 'products'
  and public.has_manager_access()
);

drop policy if exists "Authenticated delete product images" on storage.objects;
create policy "Authenticated delete product images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = 'products'
  and public.has_manager_access()
);

commit;

notify pgrst, 'reload schema';

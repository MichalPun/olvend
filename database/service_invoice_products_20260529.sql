-- Adds reusable non-stock service invoice items.

begin;

insert into public.products (
  name,
  sku,
  product_category,
  usage_type,
  base_unit,
  vat_rate,
  purchase_price,
  sale_price,
  active,
  can_be_sold_directly,
  can_be_used_in_service,
  note
)
values
  (
    'Servisní práce technik',
    'SERVIS-TECHNIK',
    'service_material',
    'service_use',
    'hod',
    21,
    0,
    null,
    true,
    true,
    true,
    'Neskladová služba pro vystavené faktury. Bez skladového pohybu.'
  ),
  (
    'Cestovné',
    'CESTOVNE',
    'service_material',
    'service_use',
    'km',
    21,
    0,
    null,
    true,
    true,
    true,
    'Neskladová služba pro vystavené faktury. Bez skladového pohybu.'
  )
on conflict (sku) do update
set
  name = excluded.name,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  vat_rate = excluded.vat_rate,
  purchase_price = excluded.purchase_price,
  sale_price = excluded.sale_price,
  active = excluded.active,
  can_be_sold_directly = excluded.can_be_sold_directly,
  can_be_used_in_service = excluded.can_be_used_in_service,
  note = excluded.note,
  updated_at = now();

commit;

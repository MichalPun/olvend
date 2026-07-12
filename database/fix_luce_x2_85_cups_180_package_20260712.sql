update public.machine_coffee_containers
set
  product_name = 'Kelímek 180 ml (50 ks)',
  refill_package_quantity = 50,
  refill_package_unit = 'ks',
  min_refill_quantity = 50,
  note = concat_ws(' ', nullif(note, ''), 'Oprava 2026-07-12: balení kelímků 180 ml je 50 ks.'),
  updated_at = now()
where machine_id = 65
  and container_code = 'Z8'
  and product_id = 78;

select
  id,
  machine_id,
  container_code,
  product_id,
  product_sku,
  product_name,
  refill_package_quantity,
  refill_package_unit,
  min_refill_quantity
from public.machine_coffee_containers
where machine_id = 65
  and container_code = 'Z8';

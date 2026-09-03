-- Kávová trasa nesmí vyjet bez základní zásoby kelímků.
-- Sklad pracuje s tyčemi po 50 ks, proto držíme na vozidle nejméně jednu tyč
-- každého aktivního kelímku používaného v recepturách.

begin;

insert into public.vehicle_auto_load_profiles (
  product_id, active, min_trip_usage_ratio, stale_vehicle_days,
  safety_stock_quantity, history_days, note
)
select
  product.id,
  true,
  0.667,
  21,
  50,
  45,
  'Bezpečnostní zásoba kelímků na vozidle: minimálně 1 tyč (50 ks), i když telemetrie pro trasu nevykáže doplnění.'
from public.products product
where product.active is distinct from false
  and (lower(product.name) like '%kelímek%' or lower(product.name) like '%kelimek%')
  and lower(coalesce(product.sku, '')) not like 'test-%'
  and exists (
    select 1
    from public.product_packages package
    where package.product_id = product.id
      and package.active is distinct from false
      and package.units_per_package = 50
  )
on conflict (product_id) do update
set active = true,
    safety_stock_quantity = greatest(public.vehicle_auto_load_profiles.safety_stock_quantity, excluded.safety_stock_quantity),
    history_days = greatest(public.vehicle_auto_load_profiles.history_days, excluded.history_days),
    note = excluded.note,
    updated_at = now();

commit;

-- OLVEND v23: první ostrý katalog pro objednávky dodavateli JiP.
-- Profily se zakládají jen pro produkty, které už mají potvrzené JiP párování
-- z přijatých dokladů. Existující ruční nastavení se nikdy nepřepisuje.

with jip_supplier as (
  select id
  from public.purchase_suppliers
  where active = true
    and lower(name) like '%jip%'
  order by id
  limit 1
),
jip_products as (
  select distinct on (spm.product_id)
    spm.supplier_id,
    spm.product_id,
    spm.supplier_item_code
  from public.supplier_product_mappings spm
  join jip_supplier js on js.id = spm.supplier_id
  join public.products p on p.id = spm.product_id and p.active = true
  where spm.active = true
    and nullif(trim(spm.supplier_item_code), '') is not null
  order by spm.product_id, spm.last_seen_at desc nulls last, spm.updated_at desc, spm.id desc
),
package_sizes as (
  select
    jp.product_id,
    coalesce(
      max(pp.units_per_package) filter (
        where pp.active = true
          and pp.units_per_package > 1
          and lower(pp.package_name) like '%cel%balen%'
      ),
      max(pp.units_per_package) filter (where pp.active = true and pp.units_per_package > 1),
      1
    )::numeric(12,3) as package_quantity
  from jip_products jp
  left join public.product_packages pp on pp.product_id = jp.product_id
  group by jp.product_id
)
insert into public.purchase_product_profiles (
  supplier_id,
  product_id,
  pilot_scope,
  active,
  reorder_enabled,
  order_weekdays,
  delivery_weekdays,
  lead_time_days,
  base_order_quantity,
  min_order_quantity,
  order_multiple_quantity,
  safety_stock_quantity,
  target_stock_quantity,
  package_quantity,
  target_cover_days,
  note
)
select
  jp.supplier_id,
  jp.product_id,
  'general',
  true,
  true,
  array[1, 4]::smallint[],
  array[2, 5]::smallint[],
  1,
  0,
  ps.package_quantity,
  ps.package_quantity,
  0,
  0,
  ps.package_quantity,
  8,
  'Automaticky založeno z potvrzené historie JiP. Zkontrolovat balení a objednávací dny při první objednávce.'
from jip_products jp
join package_sizes ps on ps.product_id = jp.product_id
on conflict (supplier_id, product_id, pilot_scope) do nothing;

comment on column public.purchase_product_profiles.package_quantity is
  'Počet základních jednotek v objednacím balení; JiP návrhy se zaokrouhlují na celé balení.';

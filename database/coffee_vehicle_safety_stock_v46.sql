-- Každé vozidlo má vedle potřeby konkrétní trasy držet nejméně 2 kg každé
-- aktivně používané kávové suroviny. Hodnota je v základní jednotce produktu.

begin;

insert into public.vehicle_auto_load_profiles (
  product_id, active, min_trip_usage_ratio, stale_vehicle_days,
  safety_stock_quantity, history_days, note
)
select distinct
  p.id,
  true,
  0.667,
  21,
  case lower(coalesce(p.base_unit, ''))
    when 'kg' then 2::numeric
    when 'g' then 2000::numeric
  end,
  45,
  'Bezpečnostní zásoba kávové suroviny na vozidle: minimálně 2 kg nad potřebu trasy.'
from public.products p
join public.machine_coffee_containers c on c.product_id = p.id and c.active = true
where p.active is distinct from false
  and lower(coalesce(p.base_unit, '')) in ('g','kg')
on conflict (product_id) do update
set active = true,
    safety_stock_quantity = excluded.safety_stock_quantity,
    history_days = greatest(public.vehicle_auto_load_profiles.history_days, excluded.history_days),
    note = excluded.note,
    updated_at = now();

commit;

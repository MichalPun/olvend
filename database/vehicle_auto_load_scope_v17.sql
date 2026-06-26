insert into public.vehicle_auto_load_profiles (
  product_id,
  active,
  min_trip_usage_ratio,
  stale_vehicle_days,
  safety_stock_quantity,
  history_days,
  note
)
select
  p.id,
  true,
  0.667,
  case
    when p.product_category = 'food_ready' or lower(coalesce(p.name, '')) like '%baget%' then 1
    when p.product_category = 'snack_ready' then 7
    when p.product_category = 'beverage_ready' then 14
    when p.product_category in ('ingredient', 'consumable', 'service_material') then 21
    else 14
  end,
  0,
  45,
  'Výchozí profil pro automatickou nakládku celého sortimentu vozidla.'
from public.products p
where p.active is distinct from false
  and p.product_category in (
    'food_ready',
    'snack_ready',
    'beverage_ready',
    'ingredient',
    'consumable',
    'service_material',
    'water_product',
    'hot_drink'
  )
on conflict (product_id) do update
set
  active = true,
  stale_vehicle_days = excluded.stale_vehicle_days,
  history_days = greatest(public.vehicle_auto_load_profiles.history_days, excluded.history_days),
  note = coalesce(public.vehicle_auto_load_profiles.note, excluded.note);

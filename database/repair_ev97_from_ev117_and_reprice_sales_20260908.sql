-- EV97 Luce X2 I / SSOS Frydek-Mistek:
-- copy the physical menu and recipes from EV117 (Obedy Blucina), while using
-- the customer-confirmed EV97 price tiers:
--   small 12 CZK, small DeLuxe 15 CZK, large 18 CZK, large DeLuxe 20 CZK.
-- Reclassify sales from 2026-09-07 (Europe/Prague) and rebuild their coffee
-- ingredient depletion without changing telemetry counter baselines.

begin;

do $$
begin
  if not exists (
    select 1 from public.machines
    where id = 77 and evidence_number = 97 and machine_type ilike 'coffee'
  ) then
    raise exception 'Target EV97 / machine_id 77 was not found.';
  end if;

  if not exists (
    select 1
    from public.machines m
    join public.locations l on l.id = m.location_id
    where m.id = 95 and m.evidence_number = 117
      and l.name = 'Obědy Blučina'
  ) then
    raise exception 'Source EV117 / Obědy Blučina / machine_id 95 was not found.';
  end if;

  if (select count(*) from public.machine_coffee_buttons where machine_id = 95 and active) <> 24 then
    raise exception 'EV117 does not have exactly 24 active coffee buttons.';
  end if;

  if (select count(*) from public.machine_coffee_containers where machine_id = 95 and active) <> 11 then
    raise exception 'EV117 does not have exactly 11 active coffee containers.';
  end if;

  if (
    select count(distinct coffee_button_id)
    from public.machine_coffee_recipe_items
    where machine_id = 95 and active
  ) <> 24 then
    raise exception 'EV117 recipes do not cover all 24 buttons.';
  end if;
end
$$;

create temporary table ev97_repair_sales on commit drop as
select id
from public.telemetry_sales_events
where machine_id = 77
  and source_event_at >= timestamptz '2026-09-06 22:00:00+00'
  and source_event_at <  timestamptz '2026-09-07 22:00:00+00';

-- Preserve the target machine's real ingredient balance by product, but first
-- reverse only the old recipe usage created by the sales being reclassified.
create temporary table ev97_stock_before_repaired_sales on commit drop as
select
  container.product_sku,
  case
    -- A zero balance may already have been clamped at zero during depletion.
    -- Do not manufacture stock by adding the recorded usage back to it.
    when max(container.current_quantity) <= 0 then 0
    else max(container.current_quantity) + coalesce(sum(depletion.quantity), 0)
  end as quantity_before_sales
from public.machine_coffee_containers container
left join public.telemetry_coffee_recipe_depletions depletion
  on depletion.coffee_container_id = container.id
 and depletion.sale_event_id in (select id from ev97_repair_sales)
where container.machine_id = 77
group by container.product_sku;

delete from public.telemetry_coffee_recipe_depletions
where sale_event_id in (select id from ev97_repair_sales);

update public.machine_coffee_containers
set active = false
where machine_id = 77;

insert into public.machine_coffee_containers (
  machine_id, container_code, product_id, product_sku, product_name,
  capacity_quantity, current_quantity, unit, refill_package_quantity,
  refill_package_unit, min_refill_quantity, sort_order, active, note
)
select
  77, source.container_code, source.product_id, source.product_sku, source.product_name,
  source.capacity_quantity, coalesce(stock.quantity_before_sales, 0), source.unit,
  source.refill_package_quantity, source.refill_package_unit,
  source.min_refill_quantity, source.sort_order, true,
  'Plánogram EV97 sjednocen s EV117 Obědy Blučina dne 2026-09-08; stav zachován podle SKU a přepočten za 2026-09-07.'
from public.machine_coffee_containers source
left join ev97_stock_before_repaired_sales stock
  on stock.product_sku = source.product_sku
where source.machine_id = 95 and source.active
on conflict (machine_id, container_code) do update set
  product_id = excluded.product_id,
  product_sku = excluded.product_sku,
  product_name = excluded.product_name,
  capacity_quantity = excluded.capacity_quantity,
  current_quantity = excluded.current_quantity,
  unit = excluded.unit,
  refill_package_quantity = excluded.refill_package_quantity,
  refill_package_unit = excluded.refill_package_unit,
  min_refill_quantity = excluded.min_refill_quantity,
  sort_order = excluded.sort_order,
  active = true,
  note = excluded.note,
  updated_at = now();

update public.machine_coffee_buttons
set active = false
where machine_id = 77;

insert into public.machine_coffee_buttons (
  machine_id, selection_code, product_id, product_sku, product_name,
  sale_price_czk, customer_price_czk,
  settlement_type, settlement_amount_czk, settlement_partner,
  settlement_billing_enabled, settlement_note,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction,
  grid_column, grid_row_from_bottom, sort_order, active, note
)
select
  77, source.selection_code, source.product_id, source.product_sku, source.product_name,
  case
    when source.selection_code in ('7', '8') then 15
    when source.selection_code in ('19', '20') then 20
    when source.sort_order <= 12 then 12
    else 18
  end,
  case
    when source.selection_code in ('7', '8') then 15
    when source.selection_code in ('19', '20') then 20
    when source.sort_order <= 12 then 12
    else 18
  end,
  source.settlement_type, source.settlement_amount_czk, source.settlement_partner,
  source.settlement_billing_enabled, source.settlement_note,
  source.planned_product_name, source.planned_product_sku, source.planned_price_czk,
  source.substitution_policy, source.allowed_substitutes, source.operator_instruction,
  source.grid_column, source.grid_row_from_bottom, source.sort_order, true,
  'Nabídka EV117 Obědy Blučina; ceny EV97 12/15/18/20 Kč; oprava 2026-09-08.'
from public.machine_coffee_buttons source
where source.machine_id = 95 and source.active
on conflict (machine_id, selection_code) do update set
  product_id = excluded.product_id,
  product_sku = excluded.product_sku,
  product_name = excluded.product_name,
  sale_price_czk = excluded.sale_price_czk,
  customer_price_czk = excluded.customer_price_czk,
  settlement_type = excluded.settlement_type,
  settlement_amount_czk = excluded.settlement_amount_czk,
  settlement_partner = excluded.settlement_partner,
  settlement_billing_enabled = excluded.settlement_billing_enabled,
  settlement_note = excluded.settlement_note,
  planned_product_name = excluded.planned_product_name,
  planned_product_sku = excluded.planned_product_sku,
  planned_price_czk = excluded.planned_price_czk,
  substitution_policy = excluded.substitution_policy,
  allowed_substitutes = excluded.allowed_substitutes,
  operator_instruction = excluded.operator_instruction,
  grid_column = excluded.grid_column,
  grid_row_from_bottom = excluded.grid_row_from_bottom,
  sort_order = excluded.sort_order,
  active = true,
  note = excluded.note,
  updated_at = now();

-- Historical recipe rows stay in place for audit references. Only the new
-- source-identical recipe set is active from now on.
update public.machine_coffee_recipe_items
set active = false, updated_at = now()
where machine_id = 77 and active;

insert into public.machine_coffee_recipe_items (
  machine_id, coffee_button_id, coffee_container_id, product_id,
  container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
)
select
  77, target_button.id, target_container.id, target_container.product_id,
  target_container.container_code, target_container.product_name,
  source_recipe.quantity_per_vend, source_recipe.unit,
  source_recipe.sort_order, true
from public.machine_coffee_recipe_items source_recipe
join public.machine_coffee_buttons source_button
  on source_button.id = source_recipe.coffee_button_id
join public.machine_coffee_buttons target_button
  on target_button.machine_id = 77
 and target_button.selection_code = source_button.selection_code
 and target_button.active
join public.machine_coffee_containers target_container
  on target_container.machine_id = 77
 and target_container.container_code = source_recipe.container_code
 and target_container.active
where source_recipe.machine_id = 95 and source_recipe.active;

update public.machine_planogram_slots
set active = false
where machine_id = 77;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, dex_price_czk, customer_price_czk,
  active, sort_order, telemetry_key,
  settlement_type, settlement_amount_czk, settlement_partner,
  settlement_billing_enabled, settlement_note,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  button.machine_id, button.selection_code, button.product_name, button.product_sku,
  button.sale_price_czk, button.sale_price_czk, button.customer_price_czk,
  true, button.sort_order, button.selection_code,
  button.settlement_type, button.settlement_amount_czk, button.settlement_partner,
  button.settlement_billing_enabled, button.settlement_note,
  button.planned_product_name, button.planned_product_sku, button.planned_price_czk,
  button.substitution_policy, button.allowed_substitutes, button.operator_instruction,
  'Telemetrický slot EV97 podle EV117; ceny 12/15/18/20 Kč; oprava 2026-09-08.'
from public.machine_coffee_buttons button
where button.machine_id = 77 and button.active
on conflict (machine_id, slot_code) do update set
  product_name = excluded.product_name,
  product_sku = excluded.product_sku,
  price_czk = excluded.price_czk,
  dex_price_czk = excluded.dex_price_czk,
  customer_price_czk = excluded.customer_price_czk,
  active = true,
  sort_order = excluded.sort_order,
  telemetry_key = excluded.telemetry_key,
  settlement_type = excluded.settlement_type,
  settlement_amount_czk = excluded.settlement_amount_czk,
  settlement_partner = excluded.settlement_partner,
  settlement_billing_enabled = excluded.settlement_billing_enabled,
  settlement_note = excluded.settlement_note,
  planned_product_name = excluded.planned_product_name,
  planned_product_sku = excluded.planned_product_sku,
  planned_price_czk = excluded.planned_price_czk,
  substitution_policy = excluded.substitution_policy,
  allowed_substitutes = excluded.allowed_substitutes,
  operator_instruction = excluded.operator_instruction,
  note = excluded.note,
  updated_at = now();

-- Reclassify the already-ingested sales, preserving cash/card quantities while
-- recalculating their monetary values from the corrected button price.
update public.telemetry_sales_events sale
set
  planogram_slot_id = slot.id,
  product_name = button.product_name,
  product_sku = button.product_sku,
  unit_price_czk = button.customer_price_czk,
  total_amount_czk = round((
    coalesce(sale.cash_quantity, 0)
    + coalesce(sale.cashless_quantity, 0)
    + coalesce(sale.unknown_payment_quantity, 0)
  ) * button.customer_price_czk, 2),
  cash_amount_czk = round(coalesce(sale.cash_quantity, 0) * button.customer_price_czk, 2),
  cashless_amount_czk = round(coalesce(sale.cashless_quantity, 0) * button.customer_price_czk, 2),
  unknown_payment_amount_czk = round(coalesce(sale.unknown_payment_quantity, 0) * button.customer_price_czk, 2)
from public.machine_coffee_buttons button
join public.machine_planogram_slots slot
  on slot.machine_id = button.machine_id
 and slot.slot_code = button.selection_code
 and slot.active
where sale.id in (select id from ev97_repair_sales)
  and button.machine_id = 77
  and button.selection_code = sale.selection_code
  and button.active;

-- The finished-drink stock records for these coffee sales are zero-balance
-- reconstruction audit rows. Keep their quantity and retag the product.
update public.telemetry_stock_depletions depletion
set product_id = product.id
from public.telemetry_sales_events sale
join public.products product on product.sku = sale.product_sku
where depletion.sale_event_id = sale.id
  and sale.id in (select id from ev97_repair_sales);

update public.stock_movements_v13 movement
set product_id = product.id
from public.telemetry_sales_events sale
join public.products product on product.sku = sale.product_sku
where sale.id in (select id from ev97_repair_sales)
  and movement.reference_id in (
    'telemetry-sale:' || sale.id,
    'telemetry-sale-reconstruction:' || sale.id
  );

-- Reapply ingredient consumption using the new active recipe set.
select public.apply_telemetry_coffee_depletion(
  coalesce(array_agg(id order by id), array[]::bigint[])
)
from ev97_repair_sales;

update public.machines
set note = concat_ws(' ', nullif(note, ''),
  '· 8. 9. 2026: plánogram sjednocen s EV117 Obědy Blučina; ceny malé 12 Kč / DeLuxe 15 Kč, velké 18 Kč / DeLuxe 20 Kč; prodeje 7. 9. 2026 přepočteny. EV97_PLANOGRAM_EV117_20260908')
where id = 77
  and coalesce(note, '') not like '%EV97_PLANOGRAM_EV117_20260908%';

do $$
begin
  if (select count(*) from public.machine_coffee_buttons where machine_id = 77 and active) <> 24 then
    raise exception 'Post-check failed: EV97 must have 24 active buttons.';
  end if;

  if (select count(*) from public.machine_coffee_containers where machine_id = 77 and active) <> 11 then
    raise exception 'Post-check failed: EV97 must have 11 active containers.';
  end if;

  if (select count(*) from public.machine_coffee_recipe_items where machine_id = 77 and active) <> 74 then
    raise exception 'Post-check failed: EV97 must have 74 active recipe items.';
  end if;

  if exists (
    select 1
    from public.machine_coffee_buttons target
    join public.machine_coffee_buttons source
      on source.machine_id = 95
     and source.selection_code = target.selection_code
     and source.active
    where target.machine_id = 77 and target.active
      and (target.product_sku, target.product_name, target.grid_column, target.grid_row_from_bottom)
          is distinct from
          (source.product_sku, source.product_name, source.grid_column, source.grid_row_from_bottom)
  ) then
    raise exception 'Post-check failed: EV97 buttons differ from EV117 menu/layout.';
  end if;

  if exists (
    select 1
    from public.machine_coffee_buttons
    where machine_id = 77 and active
      and customer_price_czk <> case
        when selection_code in ('7', '8') then 15
        when selection_code in ('19', '20') then 20
        when sort_order <= 12 then 12
        else 18
      end
  ) then
    raise exception 'Post-check failed: EV97 price tier mismatch.';
  end if;

  if exists (
    select 1
    from public.telemetry_sales_events sale
    join public.machine_coffee_buttons button
      on button.machine_id = sale.machine_id
     and button.selection_code = sale.selection_code
     and button.active
    where sale.id in (select id from ev97_repair_sales)
      and (sale.product_sku, sale.product_name, sale.unit_price_czk)
          is distinct from
          (button.product_sku, button.product_name, button.customer_price_czk)
  ) then
    raise exception 'Post-check failed: repaired EV97 sales do not match the new planogram.';
  end if;
end
$$;

commit;

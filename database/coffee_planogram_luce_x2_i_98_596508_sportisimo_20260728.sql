-- Planogram [98] Luce X2 I-2026-07-28.xlsx
-- Machine DB id 78, evidence 98, TID 596508, Sportisimo location_id 58.
-- Instant X2: physical selections 1-24, no aggregate selection 0.
-- Product layout and recipes are identical to verified machine 93 (DB id 73).

do $$
declare
  v_machine_id bigint := 78;
  v_recipe_source_machine_id bigint := 73;
begin
  update public.machines
  set location_id = 58, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; Sportisimo; TID 596508; instantní X2; plná telemetrie voleb 1–24; ceny 0 Kč.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '596508', true, 'TID 596508 pro automat 98 / Sportisimo.'),
    (v_machine_id, 'GP', '596508', true, 'TID 596508 pro automat 98 / Sportisimo.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true,
      note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select
    v_machine_id, src.container_code, src.product_id, src.product_sku, src.product_name,
    levels.capacity_quantity, levels.current_quantity, src.unit,
    src.refill_package_quantity, src.refill_package_unit, src.min_refill_quantity,
    src.sort_order, true, 'Import planogramu 98 / 2026-07-28.'
  from public.machine_coffee_containers src
  join (values
    ('Z1',1500::numeric,1265::numeric),('Z2',3000::numeric,2652::numeric),
    ('Z3',3000::numeric,1989::numeric),('Z4',3000::numeric,1870::numeric),
    ('Z5',3000::numeric,2560::numeric),('Z6',3000::numeric,2468::numeric),
    ('Z7',3000::numeric,2236::numeric),('Z8',3000::numeric,2712::numeric),
    ('Z9', 400::numeric, 331::numeric),('Z10',350::numeric,253::numeric)
  ) levels(container_code, capacity_quantity, current_quantity)
    on levels.container_code = src.container_code
  where src.machine_id = v_recipe_source_machine_id and src.active
  on conflict (machine_id, container_code) do update
  set product_id = excluded.product_id, product_sku = excluded.product_sku,
      product_name = excluded.product_name, capacity_quantity = excluded.capacity_quantity,
      current_quantity = excluded.current_quantity, unit = excluded.unit,
      refill_package_quantity = excluded.refill_package_quantity,
      refill_package_unit = excluded.refill_package_unit,
      min_refill_quantity = excluded.min_refill_quantity,
      sort_order = excluded.sort_order, active = true, note = excluded.note,
      updated_at = now();

  insert into public.machine_coffee_buttons (
    machine_id, selection_code, product_id, product_sku, product_name,
    sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    last_counter, grid_column, grid_row_from_bottom, sort_order, active, note
  )
  select
    v_machine_id, src.selection_code, src.product_id, src.product_sku, src.product_name,
    0, 0, 'none', 0, null, false, null,
    null, null, null, 'exact', null, null,
    counters.last_counter, src.grid_column, src.grid_row_from_bottom,
    src.sort_order, true, 'Import planogramu 98 / 2026-07-28.'
  from public.machine_coffee_buttons src
  join (values
    ('1',3),('2',1),('3',4),('4',7),('5',2),('6',0),
    ('7',2),('8',2),('9',1),('10',39),('11',0),('12',1),
    ('13',0),('14',1),('15',0),('16',0),('17',1),('18',1),
    ('19',2),('20',1),('21',1),('22',24),('23',1),('24',1)
  ) counters(selection_code, last_counter)
    on counters.selection_code = src.selection_code
  where src.machine_id = v_recipe_source_machine_id and src.active
  on conflict (machine_id, selection_code) do update
  set product_id = excluded.product_id, product_sku = excluded.product_sku,
      product_name = excluded.product_name, sale_price_czk = excluded.sale_price_czk,
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
      last_counter = excluded.last_counter, grid_column = excluded.grid_column,
      grid_row_from_bottom = excluded.grid_row_from_bottom,
      sort_order = excluded.sort_order, active = true, note = excluded.note,
      updated_at = now();

  delete from public.machine_coffee_recipe_items where machine_id = v_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id, coffee_button_id, coffee_container_id, product_id,
    container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
  )
  select
    v_machine_id, dst_b.id, dst_c.id, dst_c.product_id,
    dst_c.container_code, dst_c.product_name,
    src_ri.quantity_per_vend, src_ri.unit, src_ri.sort_order, true
  from public.machine_coffee_recipe_items src_ri
  join public.machine_coffee_buttons src_b on src_b.id = src_ri.coffee_button_id
  join public.machine_coffee_buttons dst_b
    on dst_b.machine_id = v_machine_id
   and dst_b.selection_code = src_b.selection_code and dst_b.active
  join public.machine_coffee_containers dst_c
    on dst_c.machine_id = v_machine_id
   and dst_c.container_code = src_ri.container_code and dst_c.active
  where src_ri.machine_id = v_recipe_source_machine_id and src_ri.active;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    active, sort_order, telemetry_key, customer_price_czk, settlement_type,
    settlement_amount_czk, settlement_partner, settlement_billing_enabled,
    settlement_note, planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction, note
  )
  select
    v_machine_id, selection_code, product_name, product_sku, 0, 0,
    true, sort_order, selection_code, 0, 'none', 0, null, false, null,
    null, null, null, 'exact', null, null,
    'Instantní X2 slot; planogram 2026-07-28 / TID 596508 / Sportisimo.'
  from public.machine_coffee_buttons where machine_id = v_machine_id and active
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name, product_sku = excluded.product_sku,
      price_czk = excluded.price_czk, dex_price_czk = excluded.dex_price_czk,
      active = true, sort_order = excluded.sort_order,
      telemetry_key = excluded.telemetry_key,
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
      note = excluded.note, updated_at = now();

  insert into public.telemetry_planogram_counters (
    provider, machine_id, planogram_slot_id, selection_code,
    last_total_count, last_event_at
  )
  select provider.provider, v_machine_id, slot.id,
         button.selection_code, button.last_counter, now()
  from public.machine_coffee_buttons button
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = button.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  where button.machine_id = v_machine_id and button.active
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

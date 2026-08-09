-- Planogram [88] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 68, evidence 88, TID 604310, WINE LIFE location_id 11.
-- Standard X2 with selections 1-24; no aggregate selection 0.

do $$
declare
  v_machine_id bigint := 68;
  v_template_machine_id bigint := 56;
begin
  update public.machines
  set location_id = 11, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I/E', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; WINE LIFE a.s.; TID 604310; plná telemetrie voleb 1–24.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '604310', true, 'TID 604310 pro automat 88 / WINE LIFE.'),
    (v_machine_id, 'GP', '604310', true, 'TID 604310 pro automat 88 / WINE LIFE.')
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
    v_machine_id, c.container_code, c.product_id, c.product_sku, c.product_name,
    c.capacity_quantity,
    case c.container_code
      when 'Z1' then 2910 when 'Z2' then 2948 when 'Z3' then 1897
      when 'Z4' then 1963 when 'Z5' then 997 when 'Z6' then 1888
      when 'Z7' then 3000 when 'Z8' then 387 when 'Z9' then 348
      when 'Z10' then 100
    end::numeric,
    c.unit, c.refill_package_quantity, c.refill_package_unit,
    c.min_refill_quantity, c.sort_order, true,
    'Import planogramu 88 / 2026-07-28.'
      || case when c.container_code = 'Z1'
        then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        else ''
      end
  from public.machine_coffee_containers c
  where c.machine_id = v_template_machine_id and c.active
    and c.container_code <> 'Z11'
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
    v_machine_id, b.selection_code, b.product_id, b.product_sku, b.product_name,
    case when b.sort_order <= 8 then 12
         when b.sort_order <= 16 then 14 else 17 end::numeric,
    case when b.sort_order <= 8 then 12
         when b.sort_order <= 16 then 14 else 17 end::numeric,
    b.settlement_type, b.settlement_amount_czk, b.settlement_partner,
    b.settlement_billing_enabled, b.settlement_note,
    b.planned_product_name, b.planned_product_sku, b.planned_price_czk,
    b.substitution_policy, b.allowed_substitutes, b.operator_instruction,
    case b.selection_code
      when '1' then 52 when '2' then 152 when '3' then 387 when '4' then 225
      when '5' then 26 when '6' then 140 when '7' then 418 when '8' then 242
      when '9' then 21 when '10' then 208 when '11' then 341 when '12' then 36
      when '13' then 232 when '14' then 697 when '15' then 90 when '16' then 15
      when '17' then 54 when '18' then 169 when '19' then 159 when '20' then 341
      when '21' then 74 when '22' then 45 when '23' then 25 when '24' then 36
    end::integer,
    b.grid_column, b.grid_row_from_bottom, b.sort_order, true,
    'Import planogramu 88 / 2026-07-28.'
  from public.machine_coffee_buttons b
  where b.machine_id = v_template_machine_id and b.active
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
    v_machine_id, target_button.id, target_container.id, target_container.product_id,
    target_container.container_code, target_container.product_name,
    source_item.quantity_per_vend, source_item.unit, source_item.sort_order, true
  from public.machine_coffee_recipe_items source_item
  join public.machine_coffee_buttons source_button
    on source_button.id = source_item.coffee_button_id
  join public.machine_coffee_buttons target_button
    on target_button.machine_id = v_machine_id
   and target_button.selection_code = source_button.selection_code
  join public.machine_coffee_containers target_container
    on target_container.machine_id = v_machine_id
   and target_container.container_code = source_item.container_code
   and target_container.active
  where source_item.machine_id = v_template_machine_id and source_item.active;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction, note
  )
  select
    v_machine_id, selection_code, product_name, product_sku,
    sale_price_czk, sale_price_czk, null, null, null, active,
    sort_order, selection_code, customer_price_czk,
    settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction,
    'Zrcadlový X2 slot; planogram 2026-07-28 / TID 604310 / WINE LIFE.'
  from public.machine_coffee_buttons where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name, product_sku = excluded.product_sku,
      price_czk = excluded.price_czk, dex_price_czk = excluded.dex_price_czk,
      active = excluded.active, sort_order = excluded.sort_order,
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
         counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',52),('2',152),('3',387),('4',225),('5',26),('6',140),
    ('7',418),('8',242),('9',21),('10',208),('11',341),('12',36),
    ('13',232),('14',697),('15',90),('16',15),('17',54),('18',169),
    ('19',159),('20',341),('21',74),('22',45),('23',25),('24',36)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

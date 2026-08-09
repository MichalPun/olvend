-- Planogram [77] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 57, evidence 77, TID 598501, OSRAM location_id 16.
-- Layout/products/prices match verified OSRAM machine 76; levels and counters are machine-specific.

do $$
declare
  v_machine_id bigint := 57;
  v_template_machine_id bigint := 56;
begin
  update public.machines
  set location_id = 16,
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce X2 I/E',
      sales_tracking_mode = 'telemetry',
      note = concat_ws(
        ' ', nullif(note, ''),
        'Planogram 2026-07-28; OSRAM Česká republika s.r.o.; TID 598501; plná telemetrie voleb 1–24.'
      )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '598501', true, 'TID 598501 pro Luce X2 I/E / automat 77 / OSRAM.'),
    (v_machine_id, 'GP', '598501', true, 'TID 598501 pro Luce X2 I/E / automat 77 / OSRAM.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id,
      telemetry_enabled = true,
      note = excluded.note,
      updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit,
    refill_package_quantity, refill_package_unit, min_refill_quantity,
    sort_order, active, note
  )
  select
    v_machine_id, c.container_code, c.product_id, c.product_sku, c.product_name,
    c.capacity_quantity,
    case c.container_code
      when 'Z1' then 2710 when 'Z2' then 2637 when 'Z3' then 1255
      when 'Z4' then 1765 when 'Z5' then 865 when 'Z6' then 1708
      when 'Z7' then 2946 when 'Z8' then 333 when 'Z9' then 330
      when 'Z10' then 98 when 'Z11' then 99
    end::numeric,
    c.unit, c.refill_package_quantity, c.refill_package_unit,
    c.min_refill_quantity, c.sort_order, true,
    'Import planogramu 77 / 2026-07-28.'
      || case when c.container_code = 'Z1'
        then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        else ''
      end
  from public.machine_coffee_containers c
  where c.machine_id = v_template_machine_id and c.active
  on conflict (machine_id, container_code) do update
  set product_id = excluded.product_id,
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
    b.sale_price_czk, b.customer_price_czk, b.settlement_type,
    b.settlement_amount_czk, b.settlement_partner,
    b.settlement_billing_enabled, b.settlement_note,
    b.planned_product_name, b.planned_product_sku, b.planned_price_czk,
    b.substitution_policy, b.allowed_substitutes, b.operator_instruction,
    case b.selection_code
      when '1' then 409 when '2' then 1152 when '3' then 734 when '4' then 214
      when '5' then 66 when '6' then 140 when '7' then 574 when '8' then 181
      when '9' then 35 when '10' then 28 when '11' then 288 when '12' then 388
      when '13' then 170 when '14' then 510 when '15' then 125 when '16' then 0
      when '17' then 387 when '18' then 488 when '19' then 116 when '20' then 304
      when '21' then 22 when '22' then 110 when '23' then 29 when '24' then 749
    end::integer,
    b.grid_column, b.grid_row_from_bottom, b.sort_order, true,
    'Import planogramu 77 / 2026-07-28.'
  from public.machine_coffee_buttons b
  where b.machine_id = v_template_machine_id and b.active
  on conflict (machine_id, selection_code) do update
  set product_id = excluded.product_id,
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
      last_counter = excluded.last_counter,
      grid_column = excluded.grid_column,
      grid_row_from_bottom = excluded.grid_row_from_bottom,
      sort_order = excluded.sort_order,
      active = true,
      note = excluded.note,
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
    'Zrcadlový X2 slot; planogram 2026-07-28 / TID 598501 / OSRAM.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name,
      product_sku = excluded.product_sku,
      price_czk = excluded.price_czk,
      dex_price_czk = excluded.dex_price_czk,
      active = excluded.active,
      sort_order = excluded.sort_order,
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
      note = excluded.note,
      updated_at = now();

  insert into public.telemetry_planogram_counters (
    provider, machine_id, planogram_slot_id, selection_code,
    last_total_count, last_event_at
  )
  select provider.provider, v_machine_id, slot.id,
         counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',409),('2',1152),('3',734),('4',214),('5',66),('6',140),
    ('7',574),('8',181),('9',35),('10',28),('11',288),('12',388),
    ('13',170),('14',510),('15',125),('16',0),('17',387),('18',488),
    ('19',116),('20',304),('21',22),('22',110),('23',29),('24',749)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

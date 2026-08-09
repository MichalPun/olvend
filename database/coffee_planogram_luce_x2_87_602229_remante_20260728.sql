-- Planogram [87] Luce X2 I_E-2026-07-28 (1).xlsx
-- Machine DB id 67, evidence 87, TID 602229, REMANTE location_id 52.

do $$
declare
  v_machine_id bigint := 67;
  v_template_machine_id bigint := 61;
begin
  update public.machines
  set location_id = 52, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I/E', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; REMANTE GROUP s.r.o.; TID 602229; plná telemetrie voleb 1–24.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '602229', true, 'TID 602229 pro automat 87 / REMANTE.'),
    (v_machine_id, 'GP', '602229', true, 'TID 602229 pro automat 87 / REMANTE.')
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
      when 'Z1' then 3000 when 'Z2' then 3000 when 'Z3' then 2000
      when 'Z4' then 2000 when 'Z5' then 1000 when 'Z6' then 2000
      when 'Z7' then 3000 when 'Z8' then 400 when 'Z9' then 350
      when 'Z10' then 100
    end::numeric,
    c.unit, c.refill_package_quantity, c.refill_package_unit,
    c.min_refill_quantity, c.sort_order, true,
    'Import planogramu 87 / 2026-07-28.'
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
         when b.sort_order <= 16 then 14 else 18 end::numeric,
    case when b.sort_order <= 8 then 12
         when b.sort_order <= 16 then 14 else 18 end::numeric,
    b.settlement_type, b.settlement_amount_czk, b.settlement_partner,
    b.settlement_billing_enabled, b.settlement_note,
    b.planned_product_name, b.planned_product_sku, b.planned_price_czk,
    b.substitution_policy, b.allowed_substitutes, b.operator_instruction,
    case b.selection_code
      when '1' then 4 when '2' then 14 when '3' then 32 when '4' then 35
      when '5' then 211 when '6' then 83 when '7' then 37 when '8' then 25
      when '9' then 138 when '10' then 9 when '11' then 28 when '12' then 79
      when '13' then 28 when '14' then 4 when '15' then 62 when '16' then 76
      when '17' then 39 when '18' then 53 when '19' then 66 when '20' then 638
      when '21' then 208 when '22' then 76 when '23' then 112 when '24' then 567
    end::integer,
    b.grid_column, b.grid_row_from_bottom, b.sort_order, true,
    'Import planogramu 87 / 2026-07-28.'
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
    v_machine_id, tb.id, tc.id, tc.product_id, tc.container_code, tc.product_name,
    si.quantity_per_vend, si.unit, si.sort_order, true
  from public.machine_coffee_recipe_items si
  join public.machine_coffee_buttons sb on sb.id = si.coffee_button_id
  join public.machine_coffee_buttons tb
    on tb.machine_id = v_machine_id and tb.selection_code = sb.selection_code
  join public.machine_coffee_containers tc
    on tc.machine_id = v_machine_id and tc.container_code = si.container_code and tc.active
  where si.machine_id = v_template_machine_id and si.active;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    active, sort_order, telemetry_key, customer_price_czk, settlement_type,
    settlement_amount_czk, settlement_partner, settlement_billing_enabled,
    settlement_note, planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction, note
  )
  select
    v_machine_id, selection_code, product_name, product_sku,
    sale_price_czk, sale_price_czk, active, sort_order, selection_code,
    customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    'X2 slot; planogram 2026-07-28 / TID 602229 / REMANTE.'
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
    ('1',4),('2',14),('3',32),('4',35),('5',211),('6',83),
    ('7',37),('8',25),('9',138),('10',9),('11',28),('12',79),
    ('13',28),('14',4),('15',62),('16',76),('17',39),('18',53),
    ('19',66),('20',638),('21',208),('22',76),('23',112),('24',567)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

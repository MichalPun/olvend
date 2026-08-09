-- Planogram [89] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 69, evidence 89, TID 596511, Sportisimo location_id 58.
-- Prices are 0 CZK; partner settlement remains disabled without a billing rule.

do $$
declare
  v_machine_id bigint := 69;
  v_template_machine_id bigint := 68;
begin
  update public.machines
  set location_id = 58, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I/E', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; Sportisimo; TID 596511; plná telemetrie voleb 1–24; ceny 0 Kč.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '596511', true, 'TID 596511 pro automat 89 / Sportisimo.'),
    (v_machine_id, 'GP', '596511', true, 'TID 596511 pro automat 89 / Sportisimo.')
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
      when 'Z1' then 2710 when 'Z2' then 2568 when 'Z3' then 1158
      when 'Z4' then 1521 when 'Z5' then 827 when 'Z6' then 1046
      when 'Z7' then 2698 when 'Z8' then 304 when 'Z9' then 307
      when 'Z10' then 100
    end::numeric,
    c.unit, c.refill_package_quantity, c.refill_package_unit,
    c.min_refill_quantity, c.sort_order, true,
    'Import planogramu 89 / 2026-07-28.'
  from public.machine_coffee_containers c
  where c.machine_id = v_template_machine_id and c.active
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
    0, 0, 'none', 0, null, false,
    'Planogram uvádí cenu 0 Kč; partnerské vyúčtování není zapnuto bez schváleného pravidla.',
    null, null, null, 'exact', null, null,
    case b.selection_code
      when '1' then 25 when '2' then 5 when '3' then 17 when '4' then 43
      when '5' then 22 when '6' then 25 when '7' then 452 when '8' then 15
      when '9' then 931 when '10' then 1 when '11' then 277 when '12' then 22
      when '13' then 11 when '14' then 1 when '15' then 85 when '16' then 4
      when '17' then 76 when '18' then 95 when '19' then 378 when '20' then 720
      when '21' then 250 when '22' then 140 when '23' then 85 when '24' then 520
    end::integer,
    b.grid_column, b.grid_row_from_bottom, b.sort_order, true,
    'Import planogramu 89 / 2026-07-28; cena 0 Kč.'
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
    'X2 slot; planogram 2026-07-28 / TID 596511 / Sportisimo.'
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
    ('1',25),('2',5),('3',17),('4',43),('5',22),('6',25),
    ('7',452),('8',15),('9',931),('10',1),('11',277),('12',22),
    ('13',11),('14',1),('15',85),('16',4),('17',76),('18',95),
    ('19',378),('20',720),('21',250),('22',140),('23',85),('24',520)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

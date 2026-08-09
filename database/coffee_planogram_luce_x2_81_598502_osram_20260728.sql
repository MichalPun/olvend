-- Planogram [81] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 61, evidence 81, TID 598502, OSRAM location_id 16.
-- Based on verified OSRAM X2 layout; selection 21 is SKU 235 Cream 300 ml.

do $$
declare
  v_machine_id bigint := 61;
  v_template_machine_id bigint := 56;
begin
  update public.machines
  set location_id = 16, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I/E', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; OSRAM Česká republika s.r.o.; TID 598502; plná telemetrie voleb 1–24.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '598502', true, 'TID 598502 pro automat 81 / OSRAM.'),
    (v_machine_id, 'GP', '598502', true, 'TID 598502 pro automat 81 / OSRAM.')
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
      when 'Z1' then 2880 when 'Z2' then 2874 when 'Z3' then 1715
      when 'Z4' then 1943 when 'Z5' then 962 when 'Z6' then 1698
      when 'Z7' then 3000 when 'Z8' then 369 when 'Z9' then 344
      when 'Z10' then 99 when 'Z11' then 100
    end::numeric,
    c.unit, c.refill_package_quantity, c.refill_package_unit,
    c.min_refill_quantity, c.sort_order, true,
    'Import planogramu 81 / 2026-07-28.'
      || case when c.container_code = 'Z1'
        then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        else ''
      end
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
    v_machine_id, b.selection_code,
    case when b.selection_code = '21' then p235.id else b.product_id end,
    case when b.selection_code = '21' then p235.sku else b.product_sku end,
    case when b.selection_code = '21' then p235.name else b.product_name end,
    b.sale_price_czk, b.customer_price_czk, b.settlement_type,
    b.settlement_amount_czk, b.settlement_partner, b.settlement_billing_enabled,
    b.settlement_note, b.planned_product_name, b.planned_product_sku,
    b.planned_price_czk, b.substitution_policy, b.allowed_substitutes,
    b.operator_instruction,
    case b.selection_code
      when '1' then 13 when '2' then 117 when '3' then 29 when '4' then 514
      when '5' then 37 when '6' then 32 when '7' then 149 when '8' then 21
      when '9' then 2 when '10' then 17 when '11' then 47 when '12' then 322
      when '13' then 75 when '14' then 553 when '15' then 227 when '16' then 6
      when '17' then 41 when '18' then 131 when '19' then 6 when '20' then 151
      when '21' then 4 when '22' then 42 when '23' then 117 when '24' then 236
    end::integer,
    b.grid_column, b.grid_row_from_bottom, b.sort_order, true,
    'Import planogramu 81 / 2026-07-28.'
  from public.machine_coffee_buttons b
  cross join lateral (select id, sku, name from public.products where sku = '235') p235
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
    v_machine_id, b.id, c.id, c.product_id, c.container_code, c.product_name,
    ri.quantity, ri.unit, ri.id, true
  from public.machine_coffee_buttons b
  join lateral (
    select r.* from public.recipes r
    where r.machine_type = 'product_catalog'
      and r.selection_code = 'product:' || b.product_id::text
    order by (r.sale_price = b.sale_price_czk) desc nulls last, r.id desc
    limit 1
  ) r on true
  join public.recipe_items ri on ri.recipe_id = r.id
  left join public.machine_coffee_containers c
    on c.machine_id = v_machine_id and c.product_id = ri.product_id
  where b.machine_id = v_machine_id and b.active;

  update public.machine_coffee_recipe_items i
  set coffee_container_id = c.id, product_id = c.product_id,
      container_code = c.container_code, ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z8'
  where i.machine_id = v_machine_id and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id
    and b.selection_code in (
      '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'
    )
    and i.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    );

  update public.machine_coffee_recipe_items i
  set coffee_container_id = c.id, product_id = c.product_id,
      container_code = c.container_code, ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z9'
  where i.machine_id = v_machine_id and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id
    and b.selection_code in ('17','18','19','20','21','22','23','24')
    and i.product_id in (
      select id from public.products
      where sku in ('53','79') or lower(name) like 'kelímek 300 ml%'
    );

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
    'Zrcadlový X2 slot; planogram 2026-07-28 / TID 598502 / OSRAM.'
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
    ('1',13),('2',117),('3',29),('4',514),('5',37),('6',32),
    ('7',149),('8',21),('9',2),('10',17),('11',47),('12',322),
    ('13',75),('14',553),('15',227),('16',6),('17',41),('18',131),
    ('19',6),('20',151),('21',4),('22',42),('23',117),('24',236)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

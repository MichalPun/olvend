-- Planogram [29] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 24, evidence 29, TID 596507, Sportisimo location_id 58.
-- Full X2 telemetry: selections 1-24, no aggregate selection 0.
-- Legacy Elite code 5 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 24;
begin
  update public.machines
  set location_id = 58,
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce X2 I/E',
      sales_tracking_mode = 'telemetry',
      note = concat_ws(
        ' ', nullif(note, ''),
        'Planogram 2026-07-28; Sportisimo; TID 596507; plná telemetrie voleb 1–24; ceny 0 Kč.'
      )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '596507', true, 'TID 596507 pro Luce X2 I/E / automat 29 / Sportisimo.'),
    (v_machine_id, 'GP', '596507', true, 'TID 596507 pro Luce X2 I/E / automat 29 / Sportisimo.')
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
    v_machine_id, d.container_code, p.id, p.sku, p.name,
    d.capacity_quantity, d.current_quantity, d.unit,
    d.package_quantity, d.package_unit, d.package_quantity,
    d.sort_order, true,
    'Import planogramu 29 / 2026-07-28.'
      || case
        when d.container_code = 'Z1'
          then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        when d.container_code = 'Z8'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1',  '201', 3000::numeric, 2500::numeric, 'g',  1000::numeric, 'g',  1),
    ('Z2',  '43',  3000::numeric, 2376::numeric, 'g',  1500::numeric, 'g',  2),
    ('Z3',  '48',  2500::numeric,  762::numeric, 'g',  1000::numeric, 'g',  3),
    ('Z4',  '47',  3000::numeric, 2514::numeric, 'g',  1000::numeric, 'g',  4),
    ('Z5',  '44',  1000::numeric,  725::numeric, 'g',   500::numeric, 'g',  5),
    ('Z6',  '46',  2500::numeric, 1226::numeric, 'g',  1000::numeric, 'g',  6),
    ('Z7',  '51',  3000::numeric, 2808::numeric, 'g',  1000::numeric, 'g',  7),
    ('Z8',  '45',   400::numeric,  314::numeric, 'ks',   50::numeric, 'ks', 8),
    ('Z9',  '53',   350::numeric,  254::numeric, 'ks',   50::numeric, 'ks', 9),
    ('Z10', '88',   100::numeric,  100::numeric, 'ks',  100::numeric, 'ks', 10)
  ) d(
    container_code, product_sku, capacity_quantity, current_quantity,
    unit, package_quantity, package_unit, sort_order
  )
  join public.products p on p.sku = d.product_sku
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
    v_machine_id, d.selection_code, p.id, p.sku, p.name,
    0, 0, 'none', 0, null, false,
    'Planogram uvádí cenu 0 Kč; fakturace partnerovi není zapnutá bez schváleného vyúčtovacího pravidla.',
    null, null, null, 'exact', null, null,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 29 / 2026-07-28. Prodejní cena 0 Kč.'
  from (values
    ('1',  '239',  806::integer, 1, 4,  1),
    ('2',  '215', 3532::integer, 1, 3,  2),
    ('3',  '222', 1984::integer, 1, 2,  3),
    ('4',  '230', 4522::integer, 1, 1,  4),
    ('5',  '233', 1073::integer, 2, 4,  5),
    ('6',  '234', 2047::integer, 2, 3,  6),
    ('7',  '236', 2757::integer, 2, 2,  7),
    ('8',  '217', 1588::integer, 2, 1,  8),
    ('9',  '224', 3559::integer, 3, 4,  9),
    ('10', '225', 1372::integer, 3, 3, 10),
    ('11', '221', 3209::integer, 3, 2, 11),
    ('12', '241', 3836::integer, 3, 1, 12),
    ('13', '226',  855::integer, 4, 4, 13),
    ('14', '227',  665::integer, 4, 3, 14),
    ('15', '244',  708::integer, 4, 2, 15),
    ('16', '228',  500::integer, 4, 1, 16),
    ('17', '240',  463::integer, 5, 4, 17),
    ('18', '216', 1105::integer, 5, 3, 18),
    ('19', '223', 1435::integer, 5, 2, 19),
    ('20', '229', 6781::integer, 5, 1, 20),
    ('21', '232', 4064::integer, 6, 4, 21),
    ('22', '218', 2616::integer, 6, 3, 22),
    ('23', '246',  280::integer, 6, 2, 23),
    ('24', '243',    1::integer, 6, 1, 24)
  ) d(
    selection_code, product_sku, last_counter,
    grid_column, grid_row_from_bottom, sort_order
  )
  join public.products p on p.sku = d.product_sku
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
    v_machine_id, button.id, container.id, recipe_item.product_id,
    container.container_code, container.product_name,
    recipe_item.quantity, recipe_item.unit, recipe_item.id, true
  from public.machine_coffee_buttons button
  join lateral (
    select recipe.*
    from public.recipes recipe
    where recipe.machine_type = 'product_catalog'
      and recipe.selection_code = 'product:' || button.product_id::text
    order by (recipe.sale_price = button.sale_price_czk) desc nulls last, recipe.id desc
    limit 1
  ) recipe on true
  join public.recipe_items recipe_item on recipe_item.recipe_id = recipe.id
  left join public.machine_coffee_containers container
    on container.machine_id = v_machine_id
   and container.product_id = recipe_item.product_id
  where button.machine_id = v_machine_id and button.active;

  update public.machine_coffee_recipe_items item
  set coffee_container_id = container.id,
      product_id = container.product_id,
      container_code = container.container_code,
      ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id and container.container_code = 'Z8'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in (
      '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'
    )
    and item.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    );

  update public.machine_coffee_recipe_items item
  set coffee_container_id = container.id,
      product_id = container.product_id,
      container_code = container.container_code,
      ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id and container.container_code = 'Z9'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in ('17','18','19','20','21','22','23','24')
    and item.product_id in (
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
    'Zrcadlový slot plné X2 telemetrie TID 596507 / Sportisimo.'
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
    ('1',806),('2',3532),('3',1984),('4',4522),('5',1073),('6',2047),
    ('7',2757),('8',1588),('9',3559),('10',1372),('11',3209),('12',3836),
    ('13',855),('14',665),('15',708),('16',500),('17',463),('18',1105),
    ('19',1435),('20',6781),('21',4064),('22',2616),('23',280),('24',1)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

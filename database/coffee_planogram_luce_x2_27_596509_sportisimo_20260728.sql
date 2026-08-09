-- Import real planogram from: Planogram [27] Luce X2 I_E-2026-07-28.xlsx
-- Machine: DB id 22, VendSoft evidence 27, TID/DeviceID 596509.
-- Location: Sportisimo (location_id 58).
-- X2 uses full per-selection telemetry for selections 1-24.
-- Legacy Excel bean code 5 / Elite is intentionally mapped to Barbera Tris SKU 201.
-- Excel prices are 0 CZK; partner settlement is not enabled without a defined billing rule.

do $$
declare
  v_machine_id bigint := 22;
begin
  update public.machines
  set
    location_id = 58,
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'Luce X2 I/E',
    sales_tracking_mode = 'telemetry',
    note = concat_ws(
      ' ',
      nullif(note, ''),
      'Planogram 2026-07-28; Sportisimo; TID 596509; plná telemetrie voleb 1–24; prodejní ceny 0 Kč.'
    )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '596509', true, 'TID 596509 pro Luce X2 I/E / automat 27 / Sportisimo.'),
    (v_machine_id, 'GP', '596509', true, 'TID 596509 pro Luce X2 I/E / automat 27 / Sportisimo.')
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
    v_machine_id,
    definition.container_code,
    product.id,
    product.sku,
    product.name,
    definition.capacity_quantity,
    definition.current_quantity,
    definition.unit,
    definition.refill_package_quantity,
    definition.refill_package_unit,
    definition.refill_package_quantity,
    definition.sort_order,
    true,
    'Import z reálného planogramu 27 / 2026-07-28.'
      || case
        when definition.container_code = 'Z1'
          then ' Excel kód 5 / Elite je podle dnešního pravidla mapovaný na Barbera Tris / SKU 201.'
        when definition.container_code = 'Z8'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1', '201', 3000::numeric, 2350::numeric, 'g',  1000::numeric, 'g',  1),
    ('Z2', '43',  3000::numeric, 2703::numeric, 'g',  1500::numeric, 'g',  2),
    ('Z3', '48',  2500::numeric, 2220::numeric, 'g',  1000::numeric, 'g',  3),
    ('Z4', '47',  3000::numeric, 2892::numeric, 'g',  1000::numeric, 'g',  4),
    ('Z5', '44',  1000::numeric,  980::numeric, 'g',   500::numeric, 'g',  5),
    ('Z6', '46',  2500::numeric, 2148::numeric, 'g',  1000::numeric, 'g',  6),
    ('Z7', '49',  3000::numeric, 2946::numeric, 'g',  1000::numeric, 'g',  7),
    ('Z8', '45',   400::numeric,  311::numeric, 'ks',   50::numeric, 'ks', 8),
    ('Z9', '53',   350::numeric,  347::numeric, 'ks',   50::numeric, 'ks', 9)
  ) as definition(
    container_code, product_sku, capacity_quantity, current_quantity,
    unit, refill_package_quantity, refill_package_unit, sort_order
  )
  join public.products product on product.sku = definition.product_sku
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
      active = excluded.active,
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
    v_machine_id,
    definition.selection_code,
    product.id,
    product.sku,
    product.name,
    0,
    0,
    'none',
    0,
    null,
    false,
    'Planogram uvádí cenu 0 Kč; fakturace partnerovi není zapnutá bez schváleného vyúčtovacího pravidla.',
    null,
    null,
    null,
    'exact',
    null,
    null,
    definition.last_counter,
    definition.grid_column,
    definition.grid_row_from_bottom,
    definition.sort_order,
    true,
    'Import z reálného planogramu 27 / 2026-07-28. Prodejní cena 0 Kč.'
  from (values
    ('1',  '239',  320::integer, 1, 4,  1),
    ('2',  '215', 1690::integer, 1, 3,  2),
    ('3',  '222', 1150::integer, 1, 2,  3),
    ('4',  '230', 4038::integer, 1, 1,  4),
    ('5',  '233',  703::integer, 2, 4,  5),
    ('6',  '234', 2407::integer, 2, 3,  6),
    ('7',  '231',  993::integer, 2, 2,  7),
    ('8',  '250', 2534::integer, 2, 1,  8),
    ('9',  '224', 1172::integer, 3, 4,  9),
    ('10', '225',  836::integer, 3, 3, 10),
    ('11', '221', 1820::integer, 3, 2, 11),
    ('12', '241', 2455::integer, 3, 1, 12),
    ('13', '226',  231::integer, 4, 4, 13),
    ('14', '227',  764::integer, 4, 3, 14),
    ('15', '244',  632::integer, 4, 2, 15),
    ('16', '228',  348::integer, 4, 1, 16),
    ('17', '240',  411::integer, 5, 4, 17),
    ('18', '216',  710::integer, 5, 3, 18),
    ('19', '223', 1022::integer, 5, 2, 19),
    ('20', '229', 3443::integer, 5, 1, 20),
    ('21', '232', 5047::integer, 6, 4, 21),
    ('22', '251', 2320::integer, 6, 3, 22),
    ('23', '246',  174::integer, 6, 2, 23),
    ('24', '243', 2981::integer, 6, 1, 24)
  ) as definition(
    selection_code, product_sku, last_counter,
    grid_column, grid_row_from_bottom, sort_order
  )
  join public.products product on product.sku = definition.product_sku
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
      active = excluded.active,
      note = excluded.note,
      updated_at = now();

  delete from public.machine_coffee_recipe_items where machine_id = v_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id, coffee_button_id, coffee_container_id, product_id,
    container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
  )
  select
    v_machine_id,
    button.id,
    container.id,
    recipe_item.product_id,
    container.container_code,
    container.product_name,
    recipe_item.quantity,
    recipe_item.unit,
    recipe_item.id,
    true
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
      select product.id
      from public.products product
      where product.sku in ('45', '79', '255')
         or lower(product.name) like 'kelímek 180 ml%'
         or lower(product.name) like 'kelímek 250 ml%'
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
      select product.id
      from public.products product
      where product.sku in ('53', '79')
         or lower(product.name) like 'kelímek 300 ml%'
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
    v_machine_id, button.selection_code, button.product_name, button.product_sku,
    button.sale_price_czk, button.sale_price_czk, null, null, null, button.active,
    button.sort_order, button.selection_code, button.customer_price_czk,
    button.settlement_type, button.settlement_amount_czk, button.settlement_partner,
    button.settlement_billing_enabled, button.settlement_note,
    button.planned_product_name, button.planned_product_sku, button.planned_price_czk,
    button.substitution_policy, button.allowed_substitutes, button.operator_instruction,
    'Zrcadlový slot pro plnou telemetrii kávy Luce X2 TID 596509 / Sportisimo.'
  from public.machine_coffee_buttons button
  where button.machine_id = v_machine_id
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
  select
    provider.provider, v_machine_id, slot.id,
    counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',320),('2',1690),('3',1150),('4',4038),('5',703),('6',2407),
    ('7',993),('8',2534),('9',1172),('10',836),('11',1820),('12',2455),
    ('13',231),('14',764),('15',632),('16',348),('17',411),('18',710),
    ('19',1022),('20',3443),('21',5047),('22',2320),('23',174),('24',2981)
  ) as counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

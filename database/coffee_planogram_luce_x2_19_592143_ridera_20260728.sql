-- Import real planogram from: Planogram [19] Luce X2 I_E-2026-07-28.xlsx
-- Machine: DB id 16, VendSoft evidence 19, TID/DeviceID 592143.
-- Location: Ridera Bohemia a.s. (location_id 69).
-- X2 uses full per-selection telemetry for selections 1-24.
-- Legacy Excel codes: bean 5 -> catalog SKU 201; Matcha 263 -> 267; Matcha 269 -> 268.

do $$
declare
  v_machine_id bigint := 16;
begin
  update public.machines
  set
    location_id = 69,
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'Luce X2 I/E',
    sales_tracking_mode = 'telemetry',
    note = concat_ws(
      ' ',
      nullif(note, ''),
      'Planogram 2026-07-28; Ridera Bohemia a.s.; TID 592143; plná telemetrie voleb 1–24.'
    )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '592143', true, 'TID 592143 pro Luce X2 I/E / automat 19 / Ridera Bohemia.'),
    (v_machine_id, 'GP', '592143', true, 'TID 592143 pro Luce X2 I/E / automat 19 / Ridera Bohemia.')
  on conflict (provider, external_machine_id) do update
  set
    machine_id = excluded.machine_id,
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
    'Import z reálného planogramu 19 / 2026-07-28.'
      || case
        when definition.container_code = 'Z1'
          then ' Excel používá historický kód 5 / Elite; skladově mapováno na Barbera Tris / SKU 201.'
        when definition.container_code = 'Z8'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1',  '201', 3000::numeric, 2900::numeric, 'g',  1000::numeric, 'g',  1),
    ('Z2',  '43',  3000::numeric, 2939::numeric, 'g',  1500::numeric, 'g',  2),
    ('Z3',  '48',  2000::numeric, 1907::numeric, 'g',  1000::numeric, 'g',  3),
    ('Z4',  '47',  2000::numeric, 1973::numeric, 'g',  1000::numeric, 'g',  4),
    ('Z5',  '44',  1000::numeric,  993::numeric, 'g',   500::numeric, 'g',  5),
    ('Z6',  '46',  2000::numeric, 1999::numeric, 'g',  1000::numeric, 'g',  6),
    ('Z7',  '262', 3000::numeric, 2999::numeric, 'g',  1000::numeric, 'g',  7),
    ('Z8',  '45',   400::numeric,  387::numeric, 'ks',   50::numeric, 'ks', 8),
    ('Z9',  '53',   350::numeric,  349::numeric, 'ks',   50::numeric, 'ks', 9),
    ('Z10', '88',   100::numeric,   99::numeric, 'ks',  100::numeric, 'ks', 10)
  ) as definition(
    container_code, product_sku, capacity_quantity, current_quantity,
    unit, refill_package_quantity, refill_package_unit, sort_order
  )
  join public.products product on product.sku = definition.product_sku
  on conflict (machine_id, container_code) do update
  set
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
    definition.sale_price_czk,
    definition.sale_price_czk,
    'none',
    0,
    null,
    false,
    null,
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
    'Import z reálného planogramu 19 / 2026-07-28.'
      || case
        when definition.selection_code = '8'
          then ' Excel kód 263 je mapovaný podle názvu Matcha Latte Malina 180 ml na katalogové SKU 267.'
        when definition.selection_code = '22'
          then ' Excel kód 269 je mapovaný podle názvu Matcha Latte Malina 300 ml na katalogové SKU 268.'
        else ''
      end
  from (values
    ('1',  '239', 15::numeric,  593::integer, 1, 4,  1),
    ('2',  '215', 15::numeric,  469::integer, 1, 3,  2),
    ('3',  '222', 15::numeric, 1261::integer, 1, 2,  3),
    ('4',  '230', 15::numeric,  632::integer, 1, 1,  4),
    ('5',  '233', 15::numeric,   67::integer, 2, 4,  5),
    ('6',  '234', 15::numeric,  208::integer, 2, 3,  6),
    ('7',  '236', 15::numeric,  348::integer, 2, 2,  7),
    ('8',  '267', 15::numeric,  240::integer, 2, 1,  8),
    ('9',  '224', 20::numeric,  259::integer, 3, 4,  9),
    ('10', '225', 20::numeric,  203::integer, 3, 3, 10),
    ('11', '221', 20::numeric,  668::integer, 3, 2, 11),
    ('12', '241', 20::numeric,  442::integer, 3, 1, 12),
    ('13', '226', 20::numeric,  516::integer, 4, 4, 13),
    ('14', '227', 20::numeric,  154::integer, 4, 3, 14),
    ('15', '244', 20::numeric,  324::integer, 4, 2, 15),
    ('16', '265', 20::numeric,  150::integer, 4, 1, 16),
    ('17', '240', 25::numeric,  604::integer, 5, 4, 17),
    ('18', '216', 25::numeric, 1213::integer, 5, 3, 18),
    ('19', '223', 25::numeric,  835::integer, 5, 2, 19),
    ('20', '229', 25::numeric, 2085::integer, 5, 1, 20),
    ('21', '232', 25::numeric,  225::integer, 6, 4, 21),
    ('22', '268', 25::numeric,  331::integer, 6, 3, 22),
    ('23', '246', 25::numeric,  126::integer, 6, 2, 23),
    ('24', '243', 25::numeric,  712::integer, 6, 1, 24)
  ) as definition(
    selection_code, product_sku, sale_price_czk, last_counter,
    grid_column, grid_row_from_bottom, sort_order
  )
  join public.products product on product.sku = definition.product_sku
  on conflict (machine_id, selection_code) do update
  set
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
    order by
      (recipe.sale_price = button.sale_price_czk) desc nulls last,
      recipe.id desc
    limit 1
  ) recipe on true
  join public.recipe_items recipe_item on recipe_item.recipe_id = recipe.id
  left join public.machine_coffee_containers container
    on container.machine_id = v_machine_id
   and container.product_id = recipe_item.product_id
  where button.machine_id = v_machine_id
    and button.active;

  -- Receptury mají historický produkt kelímku; fyzicky používáme Z8 pro 180 ml.
  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id
   and container.container_code = 'Z8'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in (
      '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'
    )
    and item.product_id in (
      select product.id
      from public.products product
      where product.sku in ('45', '79')
         or lower(product.name) like 'kelímek 180 ml%'
    );

  -- Volba 16 je v Excelu výslovně 180 ml, přesto katalogová receptura SKU 265 nese kelímek 250 ml.
  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id
   and container.container_code = 'Z8'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code = '16'
    and item.product_id in (
      select product.id
      from public.products product
      where product.sku = '255'
         or lower(product.name) like 'kelímek 250 ml%'
    );

  -- Volba 7 má v centrální receptuře white-choc SKU 51, ale export automatu nemá odpovídající zásobník.
  update public.machine_coffee_buttons
  set
    operator_instruction = 'Receptura obsahuje white-choc SKU 51, ale planogram 2026-07-28 nemá odpovídající fyzický zásobník. Nemapovat na kakao bez potvrzení skutečného osazení.',
    note = concat_ws(
      ' ',
      nullif(note, ''),
      'Receptura obsahuje white-choc SKU 51 bez fyzického zásobníku v exportu.'
    ),
    updated_at = now()
  where machine_id = v_machine_id
    and selection_code = '7';

  -- Volby 17-24 jsou 300 ml a používají Z9.
  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id
   and container.container_code = 'Z9'
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
    v_machine_id,
    button.selection_code,
    button.product_name,
    button.product_sku,
    button.sale_price_czk,
    button.sale_price_czk,
    null,
    null,
    null,
    button.active,
    button.sort_order,
    button.selection_code,
    button.customer_price_czk,
    button.settlement_type,
    button.settlement_amount_czk,
    button.settlement_partner,
    button.settlement_billing_enabled,
    button.settlement_note,
    button.planned_product_name,
    button.planned_product_sku,
    button.planned_price_czk,
    button.substitution_policy,
    button.allowed_substitutes,
    button.operator_instruction,
    'Zrcadlový slot pro plnou telemetrii kávy Luce X2 TID 592143 / Ridera Bohemia.'
  from public.machine_coffee_buttons button
  where button.machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update
  set
    product_name = excluded.product_name,
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
    provider.provider,
    v_machine_id,
    slot.id,
    counter.selection_code,
    counter.last_total_count,
    now()
  from (values
    ('1',593),('2',469),('3',1261),('4',632),('5',67),('6',208),
    ('7',348),('8',240),('9',259),('10',203),('11',668),('12',442),
    ('13',516),('14',154),('15',324),('16',150),('17',604),('18',1213),
    ('19',835),('20',2085),('21',225),('22',331),('23',126),('24',712)
  ) as counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id
   and slot.slot_code = counter.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set
    last_total_count = excluded.last_total_count,
    last_event_at = excluded.last_event_at,
    updated_at = now();
end $$;

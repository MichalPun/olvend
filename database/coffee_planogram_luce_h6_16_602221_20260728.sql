-- Import real planogram from: Planogram [16] Luce H6-2026-07-28.xlsx
-- Machine: VendSoft evidence 16, TID/DeviceID 602221.
-- Location: Brno_BVK Pisárky B jídelna.
-- H6 telemetry limitation: payment-terminal sales are available only as aggregate selection 0.
-- Selection 0 has no physical button or recipe and must not deplete a specific drink recipe.
-- Excel selection 1 carries stale product code 54; mapped by product name to catalog SKU 242.

do $$
declare
  v_machine_id bigint;
begin
  select machine.id
  into strict v_machine_id
  from public.machines machine
  where machine.evidence_number = 16
     or machine.qr_token = 'vendsoft-16'
  order by (machine.evidence_number = 16) desc
  limit 1;

  update public.machines
  set
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'Luce H6',
    sales_tracking_mode = 'telemetry',
    note = concat_ws(
      ' ',
      nullif(note, ''),
      'Planogram 2026-07-28. TID 602221; karetní prodeje terminál posílá pouze jako souhrnnou volbu 0.'
    )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id,
    provider,
    external_machine_id,
    telemetry_enabled,
    note
  )
  values
    (v_machine_id, 'IMA', '602221', true, 'TID 602221 pro Luce H6 / automat 16. Karetní prodeje jsou souhrnná volba 0.'),
    (v_machine_id, 'GP', '602221', true, 'TID 602221 pro Luce H6 / automat 16. Karetní prodeje jsou souhrnná volba 0.')
  on conflict (provider, external_machine_id) do update
  set
    machine_id = excluded.machine_id,
    telemetry_enabled = true,
    note = excluded.note,
    updated_at = now();

  update public.machine_coffee_containers
  set active = false
  where machine_id = v_machine_id;

  update public.machine_coffee_buttons
  set active = false
  where machine_id = v_machine_id;

  update public.machine_planogram_slots
  set active = false
  where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id,
    container_code,
    product_id,
    product_sku,
    product_name,
    capacity_quantity,
    current_quantity,
    unit,
    refill_package_quantity,
    refill_package_unit,
    min_refill_quantity,
    sort_order,
    active,
    note
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
    'Import z reálného planogramu 16 / 2026-07-28.'
      || case
        when definition.container_code = 'Z7'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1', '52', 1400::numeric, 1372::numeric, 'g', 700::numeric, 'g', 1),
    ('Z2', '43', 3000::numeric, 2808::numeric, 'g', 1500::numeric, 'g', 2),
    ('Z3', '44', 1000::numeric,  885::numeric, 'g', 500::numeric, 'g', 3),
    ('Z4', '48', 2000::numeric, 1656::numeric, 'g', 1000::numeric, 'g', 4),
    ('Z5', '47', 3000::numeric, 2838::numeric, 'g', 1000::numeric, 'g', 5),
    ('Z6', '46', 2000::numeric, 1890::numeric, 'g', 1000::numeric, 'g', 6),
    ('Z7', '45',  400::numeric,  352::numeric, 'ks', 50::numeric, 'ks', 7)
  ) as definition(
    container_code,
    product_sku,
    capacity_quantity,
    current_quantity,
    unit,
    refill_package_quantity,
    refill_package_unit,
    sort_order
  )
  join public.products product
    on product.sku = definition.product_sku
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
    machine_id,
    selection_code,
    product_id,
    product_sku,
    product_name,
    sale_price_czk,
    customer_price_czk,
    settlement_type,
    settlement_amount_czk,
    settlement_partner,
    settlement_billing_enabled,
    settlement_note,
    planned_product_name,
    planned_product_sku,
    planned_price_czk,
    substitution_policy,
    allowed_substitutes,
    operator_instruction,
    last_counter,
    grid_column,
    grid_row_from_bottom,
    sort_order,
    active,
    note
  )
  select
    v_machine_id,
    definition.selection_code,
    product.id,
    product.sku,
    product.name,
    14,
    14,
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
    case
      when definition.product_sku = '238'
        then 'Pozor: SKU 238 může být v katalogu neaktivní a bez receptury; dočasně pouze evidence tlačítka.'
      else null
    end,
    definition.last_counter,
    definition.grid_column,
    definition.grid_row_from_bottom,
    definition.sort_order,
    true,
    'Import z reálného planogramu 16 / 2026-07-28.'
      || case
        when definition.selection_code = '1'
          then ' Excel kód 54 je mapovaný podle názvu Latté Macchiatto 180 ml na katalogové SKU 242.'
        when definition.product_sku = '238'
          then ' Produkt SKU 238 může být v katalogu neaktivní a bez receptury.'
        else ''
      end
  from (values
    ('1',  '242', 1314::integer, 1, 4,  1),
    ('2',  '215',  581::integer, 1, 3,  2),
    ('3',  '239', 1492::integer, 1, 2,  3),
    ('4',  '215',  973::integer, 1, 1,  4),
    ('5',  '222',  351::integer, 2, 4,  5),
    ('6',  '253', 3043::integer, 2, 3,  6),
    ('7',  '222', 1623::integer, 2, 2,  7),
    ('8',  '245', 1719::integer, 2, 1,  8),
    ('9',  '233',  486::integer, 3, 4,  9),
    ('10', '238',  520::integer, 3, 3, 10),
    ('11', '234',  856::integer, 3, 2, 11),
    ('12', '230', 2122::integer, 3, 1, 12)
  ) as definition(
    selection_code,
    product_sku,
    last_counter,
    grid_column,
    grid_row_from_bottom,
    sort_order
  )
  join public.products product
    on product.sku = definition.product_sku
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

  delete from public.machine_coffee_recipe_items
  where machine_id = v_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id,
    coffee_button_id,
    coffee_container_id,
    product_id,
    container_code,
    ingredient_name,
    quantity_per_vend,
    unit,
    sort_order,
    active
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
  join public.recipe_items recipe_item
    on recipe_item.recipe_id = recipe.id
  left join public.machine_coffee_containers container
    on container.machine_id = v_machine_id
   and container.product_id = recipe_item.product_id
  where button.machine_id = v_machine_id
    and button.active = true;

  -- Receptury používají historický produkt kelímku; fyzicky se odebírá ze Z7 / SKU 45.
  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container
    on container.machine_id = button.machine_id
   and container.container_code = 'Z7'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and item.product_id in (
      select product.id
      from public.products product
      where product.sku in ('45', '79')
         or lower(product.name) like 'kelímek 180 ml%'
    );

  insert into public.machine_planogram_slots (
    machine_id,
    slot_code,
    product_name,
    product_sku,
    price_czk,
    dex_price_czk,
    capacity_units,
    current_units,
    fill_percent,
    active,
    sort_order,
    telemetry_key,
    customer_price_czk,
    settlement_type,
    settlement_amount_czk,
    settlement_partner,
    settlement_billing_enabled,
    settlement_note,
    planned_product_name,
    planned_product_sku,
    planned_price_czk,
    substitution_policy,
    allowed_substitutes,
    operator_instruction,
    note
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
    'Zrcadlový slot pro správu kávového planogramu H6 TID 602221. Import z Excel planogramu 2026-07-28.'
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

  insert into public.machine_planogram_slots (
    machine_id,
    slot_code,
    product_name,
    product_sku,
    price_czk,
    dex_price_czk,
    capacity_units,
    current_units,
    fill_percent,
    active,
    sort_order,
    telemetry_key,
    customer_price_czk,
    settlement_type,
    settlement_amount_czk,
    settlement_partner,
    settlement_billing_enabled,
    settlement_note,
    planned_product_name,
    planned_product_sku,
    planned_price_czk,
    substitution_policy,
    allowed_substitutes,
    operator_instruction,
    note
  )
  values (
    v_machine_id,
    '0',
    'Telemetrie prodej káva NEW',
    '252',
    14,
    14,
    null,
    null,
    null,
    true,
    0,
    '0',
    14,
    'none',
    0,
    null,
    false,
    'Souhrnný karetní kanál. Terminál neumí poslat konkrétní volbu nápoje.',
    null,
    null,
    null,
    'exact',
    null,
    'Souhrnná karetní telemetrie H6: neodečítat recepturu automaticky podle volby 0.',
    'Agregační telemetrický slot pro Luce H6 TID 602221. Nemá fyzické tlačítko ani recepturu; slouží pouze k zachycení karetních prodejů jako volba 0.'
  )
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
    provider,
    machine_id,
    planogram_slot_id,
    selection_code,
    last_total_count,
    last_event_at
  )
  select
    provider.provider,
    v_machine_id,
    slot.id,
    counter.selection_code,
    counter.last_total_count,
    now()
  from (values
    ('0',     0),
    ('1',  1314),
    ('2',   581),
    ('3',  1492),
    ('4',   973),
    ('5',   351),
    ('6',  3043),
    ('7',  1623),
    ('8',  1719),
    ('9',   486),
    ('10',  520),
    ('11',  856),
    ('12', 2122)
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

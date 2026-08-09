-- Planogram [45] Luce X1 E-2026-07-28.xlsx
-- Machine DB id 39, evidence 45, TID 592151.
-- Location: Bohumín, Střední škola hl. budova (location_id 4).
-- X1 reports aggregate telemetry as selection 0; selections 1-16 remain physical planogram buttons.
-- Elite / code 5 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 39;
begin
  update public.machines
  set location_id = 4,
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce X1 E',
      sales_tracking_mode = 'telemetry',
      note = concat_ws(
        ' ', nullif(note, ''),
        'Planogram 2026-07-28; Bohumín Střední škola hl. budova; TID 592151; souhrnná telemetrie volbou 0.'
      )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '592151', true, 'TID 592151 pro Luce X1 E / automat 45. Souhrnný kanál volba 0.'),
    (v_machine_id, 'GP', '592151', true, 'TID 592151 pro Luce X1 E / automat 45. Souhrnný kanál volba 0.')
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
    'Import planogramu 45 / 2026-07-28.'
      || case
        when d.container_code = 'Z1'
          then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        when d.container_code = 'Z7'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1','201',2000::numeric,1915::numeric,'g',1000::numeric,'g',1),
    ('Z2','43', 3000::numeric,2935::numeric,'g',1500::numeric,'g',2),
    ('Z3','48', 2000::numeric,1855::numeric,'g',1000::numeric,'g',3),
    ('Z4','47', 2000::numeric,1945::numeric,'g',1000::numeric,'g',4),
    ('Z5','46', 2000::numeric,1864::numeric,'g',1000::numeric,'g',5),
    ('Z6','49', 2000::numeric,1949::numeric,'g',1000::numeric,'g',6),
    ('Z7','45',  400::numeric, 383::numeric,'ks', 50::numeric,'ks',7)
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
    14, 14, 'none', 0, null, false, null,
    null, null, null, 'exact', null,
    case
      when d.product_sku = '238'
        then 'SKU 238 je v katalogu neaktivní a bez receptury; tlačítko je pouze evidenční.'
      else null
    end,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 45 / 2026-07-28.'
      || case
        when d.product_sku = '238'
          then ' Produkt SKU 238 je v katalogu neaktivní a bez receptury.'
        else ''
      end
  from (values
    ('1', '225', 48::integer,  1,4, 1),
    ('2', '227',358::integer,  1,3, 2),
    ('3', '224',144::integer,  1,2, 3),
    ('4', '226',647::integer,  1,1, 4),
    ('5', '241',371::integer,  2,4, 5),
    ('6', '241',491::integer,  2,3, 6),
    ('7', '241',132::integer,  2,2, 7),
    ('8', '221',  9::integer,  2,1, 8),
    ('9', '244',168::integer,  3,4, 9),
    ('10','231',251::integer,  3,3,10),
    ('11','233',343::integer,  3,2,11),
    ('12','234',111::integer,  3,1,12),
    ('13','226', 88::integer,  4,4,13),
    ('14','230',785::integer,  4,3,14),
    ('15','238',206::integer,  4,2,15),
    ('16','250',452::integer,  4,1,16)
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

  -- X1 nemá samostatný FD-coffee zásobník; kávová složka se fyzicky odebírá ze Z1 / Tris.
  update public.machine_coffee_recipe_items item
  set coffee_container_id = container.id,
      container_code = container.container_code,
      ingredient_name = container.product_name
  from public.machine_coffee_containers container
  where item.machine_id = v_machine_id
    and item.product_id in (
      select id from public.products where sku = '44'
    )
    and item.coffee_container_id is null
    and container.machine_id = v_machine_id
    and container.container_code = 'Z1'
    and container.active;

  update public.machine_coffee_recipe_items item
  set coffee_container_id = container.id,
      product_id = container.product_id,
      container_code = container.container_code,
      ingredient_name = container.product_name
  from public.machine_coffee_containers container
  where item.machine_id = v_machine_id
    and item.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    )
    and container.machine_id = v_machine_id
    and container.container_code = 'Z7'
    and container.active;

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
    'Fyzická X1 volba; planogram 2026-07-28 / TID 592151.'
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

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction, note
  )
  values (
    v_machine_id, '0', 'Telemetrie prodej káva NEW', '252', 14, 14,
    null, null, null, true, 0, '0', 14, 'none', 0, null, false,
    'Souhrnný X1 kanál bez konkrétní volby nápoje.',
    null, null, null, 'exact', null,
    'Souhrnná telemetrie X1: neodečítat recepturu automaticky podle volby 0.',
    'Agregační slot X1 TID 592151; nemá fyzické tlačítko ani recepturu.'
  )
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name,
      product_sku = excluded.product_sku,
      price_czk = excluded.price_czk,
      dex_price_czk = excluded.dex_price_czk,
      active = true,
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
    ('1',48),('2',358),('3',144),('4',647),
    ('5',371),('6',491),('7',132),('8',9),
    ('9',168),('10',251),('11',343),('12',111),
    ('13',88),('14',785),('15',206),('16',452)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

-- Import real planogram from: Planogram [102] rhFS1 buttons16-2026-07-27.xlsx
-- Machine: DB id 82, VendSoft evidence 102, TID/DeviceID 604308.
-- Location: Břeclav - AVE (location_id 17).
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy Elite code 5.

do $$
declare
  v_machine_id bigint := 82;
begin
  update public.machines
  set
    location_id = 17,
    note = 'Import z VendSoft exportu; původní kód 102; lokalita Břeclav_AVE. Telemetry ID: 604308. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '604308', true, 'TID 604308 pro rhFS1 buttons16 / automat 102.'),
    (v_machine_id, 'GP', '604308', true, 'TID 604308 pro rhFS1 buttons16 / automat 102.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Barbera Tris 1 kg', 3000, 2570, 'g', 1000, 'g', 1000, 1, true, 'Kod ve VendSoft exportu: 5 / Elite; skladove pouzivame Barbera Tris 1 kg / SKU 201. Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 2643, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z3', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1000, 921, 'g', 500, 'g', 500, 3, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z4', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 3000, 2257, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z5', 106, '47', 'oVe DRINK WITH COCOA ZETA 1 kg', 3000, 2620, 'g', 1000, 'g', 1000, 5, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z6', 110, '46', 'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g', 3000, 2720, 'g', 1000, 'g', 1000, 6, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z7', 109, '49', 'oVe FRESH DRINK LEMON 1 kg', 3000, 2999, 'g', 1000, 'g', 1000, 7, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z8', 79, '255', 'Kelímek 250 ml (100 ks)', 400, 400, 'ks', 100, 'ks', 100, 8, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, 'Z9', 136, '88', 'VÍČKO HUHTAMAKI PLAST ČERNÉ 300ml', 100, 100, 'ks', 100, 'ks', 100, 9, true, 'Import z realneho planogramu 102 / 2026-07-27.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 140, '239', 'Černá káva 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 1, 4, 1, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '2', 31, '215', 'Bílá káva 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 1, 3, 2, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '3', 36, '222', 'Cappuccino 180 ml I NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 1, 2, 3, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '4', 96, '245', 'MOCCACCINO 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 1, 1, 4, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '5', 71, '233', 'Kakaový nápoj 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 2, 4, 5, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '6', 73, '234', 'Kakaový nápoj Cream 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 2, 3, 6, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '7', 68, '230', 'Irish Cream 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 2, 2, 7, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '8', 129, '250', 'Tea 180 ml NEW', 7, 7, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 2, 1, 8, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '9', 58, '224', 'Espresso NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 3, 4, 9, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '10', 54, '225', 'Espresso Bílé NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 3, 3, 10, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '11', 55, '226', 'Espresso Lungo 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 3, 2, 11, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '12', 56, '227', 'Espresso Lungo bílé 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 3, 1, 12, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '13', 88, '241', 'LATTE MACCHIATO (E) 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 4, 4, 13, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '14', 35, '221', 'CAPPUCCINO (E) 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 4, 3, 14, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '15', 95, '244', 'MOCCACCINO (E) 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 4, 2, 15, true, 'Import z realneho planogramu 102 / 2026-07-27.'),
    (v_machine_id, '16', 102, '247', 'OLMIKA Cappuccino 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 0, 4, 1, 16, true, 'Import z realneho planogramu 102 / 2026-07-27.')
  on conflict (machine_id, selection_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, sale_price_czk=excluded.sale_price_czk, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, last_counter=excluded.last_counter, grid_column=excluded.grid_column, grid_row_from_bottom=excluded.grid_row_from_bottom, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  delete from public.machine_coffee_recipe_items where machine_id = v_machine_id;
  insert into public.machine_coffee_recipe_items (machine_id, coffee_button_id, coffee_container_id, product_id, container_code, ingredient_name, quantity_per_vend, unit, sort_order, active)
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
  left join public.machine_coffee_containers container on container.machine_id = v_machine_id and container.product_id = recipe_item.product_id
  where button.machine_id = v_machine_id
    and button.active = true;

  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_containers container
  where item.machine_id = v_machine_id
    and item.product_id in (107, 108)
    and container.machine_id = v_machine_id
    and container.container_code = 'Z1'
    and container.active = true;

  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_containers container
  where item.machine_id = v_machine_id
    and item.product_id in (78, 79)
    and container.machine_id = v_machine_id
    and container.container_code = 'Z8'
    and container.active = true;

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro telemetrii kavy TID 604308. Import z Excel planogramu 2026-07-27.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();

  insert into public.telemetry_planogram_counters (provider, machine_id, planogram_slot_id, selection_code, last_total_count, last_event_at)
  select provider.provider, v_machine_id, slot.id, values_table.selection_code, values_table.last_total_count, now()
  from (values
    ('1', 0),
    ('2', 0),
    ('3', 0),
    ('4', 0),
    ('5', 0),
    ('6', 0),
    ('7', 0),
    ('8', 0),
    ('9', 0),
    ('10', 0),
    ('11', 0),
    ('12', 0),
    ('13', 0),
    ('14', 0),
    ('15', 0),
    ('16', 0)
  ) as values_table(selection_code, last_total_count)
  join public.machine_planogram_slots slot on slot.machine_id = v_machine_id and slot.slot_code = values_table.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update set last_total_count=excluded.last_total_count, last_event_at=excluded.last_event_at, updated_at=now();
end $$;

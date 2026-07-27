-- Import real planogram from: Planogram [31] Luce X1 I_E-2026-07-27.xlsx
-- Machine: DB id 26, VendSoft evidence 31, TID/DeviceID 592149.
-- Location: Hustopece - Domov senioru (location_id 28).
-- X1 note: keep aggregate telemetry selection 0 as a fallback channel.
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy Elite code 5.

do $$
declare
  v_machine_id bigint := 26;
begin
  update public.machines
  set
    location_id = 28,
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'Luce X1 I/E',
    note = 'Import z VendSoft exportu; puvodni kod 31; lokalita Hustopece_Domov senioru. Telemetry ID: 592149. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '592149', true, 'TID 592149 pro Luce X1 I/E / automat 31. X1 muze posilat souhrnnou volbu 0.'),
    (v_machine_id, 'GP', '592149', true, 'TID 592149 pro Luce X1 I/E / automat 31. X1 muze posilat souhrnnou volbu 0.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Barbera Tris 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 1, true, 'Kod ve VendSoft exportu: 5 / Elite; skladove pouzivame Barbera Tris 1 kg / SKU 201. Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 3000, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 2000, 1999, 'g', 1000, 'g', 1000, 3, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA 1 kg', 2000, 1999, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z5', 110, '46', 'Irish Cream 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 5, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z6', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1000, 1000, 'g', 500, 'g', 500, 6, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, 'Z7', 78, '45', 'Kelimek 180 ml', 400, 399, 'ks', 50, 'ks', 50, 7, true, 'Import z realneho planogramu 31 / 2026-07-27. V exportu nazev obsahuje 100 ks, skladove doplnujeme po 50 ks.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 58, '224', 'Espresso NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 101, 1, 4, 1, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '2', 55, '226', 'Espresso Lungo 180 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 245, 1, 3, 2, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '3', 54, '225', 'Espresso Bile NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 95, 1, 2, 3, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '4', 56, '227', 'Espresso Lungo bile 180 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 239, 1, 1, 4, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '5', 88, '241', 'LATTE MACCHIATO (E) 180 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 261, 2, 4, 5, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '6', 59, '228', 'ESPRESSO S KAKAOVYM NAPOJEM NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 84, 2, 3, 6, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '7', 35, '221', 'CAPPUCCINO (E) 180 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 1062, 2, 2, 7, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '8', 95, '244', 'MOCCACCINO (E) 180 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 92, 2, 1, 8, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '9', 140, '239', 'Cerna kava 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 289, 3, 4, 9, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '10', 31, '215', 'Bila kava 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 446, 3, 3, 10, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '11', 36, '222', 'Cappuccino 180 ml I NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 464, 3, 2, 11, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '12', 96, '245', 'MOCCACCINO 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 27, 3, 1, 12, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '13', 89, '242', 'LATTE MACCHIATO 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 607, 4, 4, 13, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '14', 68, '230', 'Irish Cream 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 810, 4, 3, 14, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '15', 71, '233', 'Kakaovy napoj 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 264, 4, 2, 15, true, 'Import z realneho planogramu 31 / 2026-07-27.'),
    (v_machine_id, '16', 73, '234', 'Kakaovy napoj Cream 180 ml NEW', 16, 16, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 426, 4, 1, 16, true, 'Import z realneho planogramu 31 / 2026-07-27.')
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

  -- X1 export nema samostatny FD coffee zasobnik; kavovou slozku proto mapujeme na fyzicky Z1 / Tris.
  update public.machine_coffee_recipe_items recipe_item
  set
    coffee_container_id = container.id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_containers container
  where recipe_item.machine_id = v_machine_id
    and recipe_item.product_id = 108
    and recipe_item.coffee_container_id is null
    and container.machine_id = v_machine_id
    and container.container_code = 'Z1'
    and container.active = true;

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro spravu kavoveho planogramu X1 TID 592149. Import z Excel planogramu 2026-07-27.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  values (v_machine_id, '0', 'Telemetrie prodej kava NEW', '252', 0, 0, null, null, null, true, 0, '0', 0, 'none', 0, null, false, 'Souhrnny X1 kanal. Cena se u volby 0 nepocita automaticky, protoze Excel obsahuje souhrn pro 18 Kc i 16 Kc.', null, null, null, 'exact', null, 'Souhrnna telemetrie X1: neodecitat recepturu automaticky podle volby 0.', 'Agregacni telemetricky slot pro Luce X1 I/E TID 592149. Neexistuje odpovidajici fyzicke tlacitko ani receptura; slouzi jen k zachyceni prodeje, pokud terminal posila pouze volbu 0.')
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();

  insert into public.telemetry_planogram_counters (provider, machine_id, planogram_slot_id, selection_code, last_total_count, last_event_at)
  select provider.provider, v_machine_id, slot.id, values_table.selection_code, values_table.last_total_count, now()
  from (values
    ('0', 0),
    ('1', 101),
    ('2', 245),
    ('3', 95),
    ('4', 239),
    ('5', 261),
    ('6', 84),
    ('7', 1062),
    ('8', 92),
    ('9', 289),
    ('10', 446),
    ('11', 464),
    ('12', 27),
    ('13', 607),
    ('14', 810),
    ('15', 264),
    ('16', 426)
  ) as values_table(selection_code, last_total_count)
  join public.machine_planogram_slots slot on slot.machine_id = v_machine_id and slot.slot_code = values_table.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update set last_total_count=excluded.last_total_count, last_event_at=excluded.last_event_at, updated_at=now();
end $$;

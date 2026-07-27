-- Import real planogram from: Planogram [18] Luce X1 I_E-2026-07-27.xlsx
-- Machine: DB id 15, VendSoft evidence 18, TID/DeviceID 604306.
-- Location: Jihlava - VOS (location_id 34).
-- X1 note: keep aggregate telemetry selection 0 as a fallback channel.
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy Elite code 5.

do $$
declare
  v_machine_id bigint := 15;
begin
  update public.machines
  set
    location_id = 34,
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'Luce X1 I/E',
    note = 'Import z VendSoft exportu; puvodni kod 18; lokalita Jihlava_VOS. Telemetry ID: 604306. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '604306', true, 'TID 604306 pro Luce X1 I/E / automat 18. X1 muze posilat souhrnnou volbu 0.'),
    (v_machine_id, 'GP', '604306', true, 'TID 604306 pro Luce X1 I/E / automat 18. X1 muze posilat souhrnnou volbu 0.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Barbera Tris 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 1, true, 'Kod ve VendSoft exportu: 5 / Elite; skladove pouzivame Barbera Tris 1 kg / SKU 201. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 1000, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 3, true, 'Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z5', 110, '46', 'Irish Cream 1 kg', 2000, 2000, 'g', 1000, 'g', 1000, 5, true, 'Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z6', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1000, 1000, 'g', 500, 'g', 500, 6, true, 'Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, 'Z7', 78, '45', 'Kelimek 180 ml', 400, 200, 'ks', 50, 'ks', 50, 7, true, 'Import z realneho planogramu 18 / 2026-07-27. V exportu nazev obsahuje 100 ks, skladove doplnujeme po 50 ks.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '0', 131, '252', 'Telemetrie prodej kava', 14, 14, 'none', 0, null, false, 'Souhrnny X1 kanal. Pokud terminal posle jen volbu 0, prodej zachytit, ale automaticky neodecitat recepturu.', null, null, null, 'exact', null, 'Souhrnna telemetrie X1: neodecitat recepturu automaticky podle volby 0.', 0, null, null, 0, true, 'Agregacni telemetricky kanal X1 z Excel planogramu 18 / 2026-07-27.'),
    (v_machine_id, '1', 54, '225', 'Espresso Bile 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 616, 1, 4, 1, true, 'Excel kod 91. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '2', 56, '227', 'Espresso Lungo bile 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 98, 1, 3, 2, true, 'Excel kod 92. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '3', 58, '224', 'Espresso 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 50, 1, 2, 3, true, 'Excel kod 89. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '4', 55, '226', 'Espresso Lungo 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 106, 1, 1, 4, true, 'Excel kod 90. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '5', 88, '241', 'ESPRESSO LATTE MACCHIATO 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 1347, 2, 4, 5, true, 'Excel kod 93. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '6', 35, '221', 'ESPRESSO CAPPUCCINO 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 1086, 2, 3, 6, true, 'Excel kod 95. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '7', 95, '244', 'ESPRESSO MOCCACCINO 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 826, 2, 2, 7, true, 'Excel kod 96. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '8', 69, '231', 'Irska kava 180 ml', 14, 14, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 310, 2, 1, 8, true, 'Excel kod 120 / Irska espresso kava. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '9', 140, '239', 'Cerna kava 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 784, 3, 4, 9, true, 'Excel kod 56. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '10', 31, '215', 'Bila kava 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 619, 3, 3, 10, true, 'Excel kod 55. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '11', 71, '233', 'Kakaovy napoj 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 427, 3, 2, 11, true, 'Excel kod 62. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '12', 73, '234', 'Kakaovy napoj Cream 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 647, 3, 1, 12, true, 'Excel kod 64. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '13', 36, '222', 'Cappuccino 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 2521, 4, 4, 13, true, 'Excel kod 60. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '14', 96, '245', 'MOCCACCINO 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 1234, 4, 3, 14, true, 'Excel kod 61. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '15', 68, '230', 'Irish Cappuccino 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 1278, 4, 2, 15, true, 'Excel kod 65 / Irish Cream 180 ml. Import z realneho planogramu 18 / 2026-07-27.'),
    (v_machine_id, '16', 69, '231', 'Irska kava 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 524, 4, 1, 16, true, 'Excel kod 119. Import z realneho planogramu 18 / 2026-07-27.')
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
    and button.active = true
    and button.selection_code <> '0';

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro spravu kavoveho planogramu X1 TID 604306. Import z Excel planogramu 2026-07-27.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();

  insert into public.telemetry_planogram_counters (provider, machine_id, planogram_slot_id, selection_code, last_total_count, last_event_at)
  select provider.provider, v_machine_id, slot.id, values_table.selection_code, values_table.last_total_count, now()
  from (values
    ('0', 0),
    ('1', 616),
    ('2', 98),
    ('3', 50),
    ('4', 106),
    ('5', 1347),
    ('6', 1086),
    ('7', 826),
    ('8', 310),
    ('9', 784),
    ('10', 619),
    ('11', 427),
    ('12', 647),
    ('13', 2521),
    ('14', 1234),
    ('15', 1278),
    ('16', 524)
  ) as values_table(selection_code, last_total_count)
  join public.machine_planogram_slots slot on slot.machine_id = v_machine_id and slot.slot_code = values_table.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update set last_total_count=excluded.last_total_count, last_event_at=excluded.last_event_at, updated_at=now();
end $$;

select
  (select count(*) from public.machine_coffee_containers where machine_id = 15 and active) as active_containers,
  (select count(*) from public.machine_coffee_buttons where machine_id = 15 and active) as active_buttons,
  (select count(*) from public.machine_planogram_slots where machine_id = 15 and active) as active_slots,
  (select count(*) from public.machine_coffee_recipe_items where machine_id = 15 and active) as active_recipe_items,
  (select count(*) from public.machine_coffee_recipe_items where machine_id = 15 and active and coffee_container_id is null) as recipe_items_without_container,
  (select count(*) from public.telemetry_planogram_counters where machine_id = 15 and selection_code in ('0','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16')) as counter_baselines,
  (select string_agg(provider || ':' || external_machine_id, ', ' order by provider) from public.machine_external_links where machine_id = 15 and external_machine_id = '604306') as telemetry_links;

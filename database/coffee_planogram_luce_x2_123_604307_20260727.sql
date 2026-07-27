-- Import real planogram from: Planogram [123] Luce X2 I-2026-07-27.xlsx
-- Machine: DB id 101, VendSoft evidence 123, TID/DeviceID 604307.
-- Location: Rigum / RIGUM, s.r.o. (location_id 23).
-- Excel has empty last counter values, so no telemetry counter baseline is inserted here.

do $$
declare
  v_machine_id bigint := 101;
begin
  update public.machines
  set
    location_id = 23,
    note = 'Import z VendSoft exportu; původní kód 123; lokalita RIGUM, s.r.o. Telemetry ID: 604307. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '604307', true, 'TID 604307 pro Luce X2 I / automat 123.'),
    (v_machine_id, 'GP', '604307', true, 'TID 604307 pro Luce X2 I / automat 123.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1500, 1117, 'g', 500, 'g', 500, 1, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 2406, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 3000, 1536, 'g', 1000, 'g', 1000, 3, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA ZETA 1 kg', 3000, 2433, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z5', 105, '51', 'oVe DRINK WITH CHOC WHITE FLAVOUR 1000g', 3000, 2382, 'g', 1000, 'g', 1000, 5, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z6', 103, '197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g', 3000, 2740, 'g', 1000, 'g', 1000, 6, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z7', 110, '46', 'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g', 3000, 1534, 'g', 1000, 'g', 1000, 7, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z8', 109, '49', 'oVe FRESH DRINK LEMON 1 kg', 3000, 2999, 'g', 1000, 'g', 1000, 8, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z9', 78, '45', 'Kelímek 180 ml (50 ks)', 400, 329, 'ks', 50, 'ks', 50, 9, true, 'Import z realneho planogramu 123 / 2026-07-27. V exportu nazev obsahuje 100 ks, skladove doplnujeme po 50 ks.'),
    (v_machine_id, 'Z10', 80, '53', 'Kelímek 300 ml (50 ks)', 350, 228, 'ks', 50, 'ks', 50, 10, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, 'Z11', 136, '88', 'VÍČKO HUHTAMAKI PLAST ČERNÉ 300ml', 100, 100, 'ks', 100, 'ks', 100, 11, true, 'Import z realneho planogramu 123 / 2026-07-27.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 140, '239', 'Černá káva 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 4, 1, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '2', 31, '215', 'Bílá káva 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 3, 2, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '3', 36, '222', 'Cappuccino 180 ml I NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 2, 3, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '4', 96, '245', 'MOCCACCINO 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 1, 4, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '5', 89, '242', 'LATTE MACCHIATO 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 4, 5, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '6', 33, '219', 'Cafe+Co 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 3, 6, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '7', 71, '233', 'Kakaový nápoj 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 2, 7, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '8', 75, '236', 'KAKAOVÝ NÁPOJ DE LUXE 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 1, 8, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '9', 68, '230', 'Irish Cream 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 4, 9, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '10', 114, '248', 'Pistácie 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 3, 10, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '11', 129, '250', 'Tea 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 2, 11, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '12', 29, '217', 'Bílá krémová 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 1, 12, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '13', 141, '240', 'Černá káva 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 4, 13, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '14', 32, '216', 'Bílá káva 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 3, 14, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '15', 37, '223', 'Cappuccino 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 2, 15, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '16', 97, '246', 'MOCCACCINO 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 1, 16, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '17', 90, '243', 'LATTE MACCHIATO 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 4, 17, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '18', 34, '220', 'Cafe+Co 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 3, 18, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '19', 72, '232', 'Kakaový nápoj 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 2, 19, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '20', 76, '237', 'KAKAOVÝ NÁPOJ DE LUXE 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 1, 20, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '21', 67, '229', 'Irish Cappuccino 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 4, 21, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '22', 115, '249', 'Pistácie 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 3, 22, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '23', 130, '251', 'Tea 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 2, 23, true, 'Import z realneho planogramu 123 / 2026-07-27.'),
    (v_machine_id, '24', 30, '218', 'Bílá krémová 300 ml NEW', 18, 18, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 1, 24, true, 'Import z realneho planogramu 123 / 2026-07-27.')
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
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container on container.machine_id = button.machine_id and container.container_code = 'Z9'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in ('1','2','3','4','5','6','7','8','9','10','11','12')
    and item.product_id = 79;

  update public.machine_coffee_recipe_items item
  set
    coffee_container_id = container.id,
    product_id = container.product_id,
    container_code = container.container_code,
    ingredient_name = container.product_name
  from public.machine_coffee_buttons button
  join public.machine_coffee_containers container on container.machine_id = button.machine_id and container.container_code = 'Z10'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in ('13','14','15','16','17','18','19','20','21','22','23','24')
    and item.product_id = 79;

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro telemetrii kavy TID 604307. Import z Excel planogramu 2026-07-27. Counter baseline se nastavi az prvnim DEXem.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();
end $$;

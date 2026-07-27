-- Import real planogram from: Planogram [110] rhFS1 touch 21,5-2026-07-27.xlsx
-- Machine: DB id 90, VendSoft evidence 110, TID/DeviceID 592148.
-- Location: Velke Mezirici - Kabelove Bubny (location_id 62).
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy Elite code 5.
-- Excel has empty last counter values, so no telemetry counter baseline is inserted here.

do $$
declare
  v_machine_id bigint := 90;
begin
  update public.machines
  set
    location_id = 62,
    machine_type = 'Coffee',
    brand = 'Rheavendors',
    name = 'rhFS1 touch 21,5',
    note = 'Import z VendSoft exportu; puvodni kod 110; lokalita Velke Mezirici_Kabelove Bubny. Telemetry ID: 592148. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '592148', true, 'TID 592148 pro rhFS1 touch 21,5 / automat 110.'),
    (v_machine_id, 'GP', '592148', true, 'TID 592148 pro rhFS1 touch 21,5 / automat 110.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Barbera Tris 1 kg', 2000, 1030, 'g', 1000, 'g', 1000, 1, true, 'Kod ve VendSoft exportu: 5 / Elite; skladove pouzivame Barbera Tris 1 kg / SKU 201. Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 2242, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 3000, 1673, 'g', 1000, 'g', 1000, 3, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA 1 kg', 3000, 2298, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z5', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1500, 1334, 'g', 500, 'g', 500, 5, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z6', 110, '46', 'Irish Cream 1 kg', 3000, 2655, 'g', 1000, 'g', 1000, 6, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z7', 103, '197', 'oVe BASE WITH PISTACHIO FLAVOUR 1000g', 3000, 2933, 'g', 1000, 'g', 1000, 7, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, 'Z8', 79, '255', 'Kelimek 250 ml', 400, 386, 'ks', 100, 'ks', 100, 8, true, 'Import z realneho planogramu 110 / 2026-07-27. V exportu nazev obsahuje 100 ks.'),
    (v_machine_id, 'Z9', 136, '88', 'VICKO HUHTAMAKI PLAST CERNE 300ml', 100, 99, 'ks', 100, 'ks', 100, 9, true, 'Import z realneho planogramu 110 / 2026-07-27.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 58, '224', 'Espresso NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 4, 1, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '2', 55, '226', 'Espresso Lungo 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 3, 2, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '3', 57, '256', 'Espresso Macchiatto', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 2, 3, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '4', 56, '227', 'Espresso Lungo bile 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 1, 4, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '5', 88, '241', 'LATTE MACCHIATO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 4, 5, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '6', 35, '221', 'CAPPUCCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 3, 6, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '7', 95, '244', 'MOCCACCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 2, 7, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '8', 117, '257', 'Pistaciove Latte (E)', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 1, 8, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '9', 140, '239', 'Cerna kava 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 4, 9, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '10', 31, '215', 'Bila kava 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 3, 10, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '11', 71, '233', 'Kakaovy napoj 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 2, 11, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '12', 68, '230', 'Irish Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 1, 12, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '13', 102, '247', 'OLMIKA Cappuccino 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 4, 13, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '14', 73, '234', 'Kakaovy napoj Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 3, 14, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '15', 114, '248', 'Pistacie 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 2, 15, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '16', 116, '258', 'Pistaciova kava', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 1, 16, true, 'Import z realneho planogramu 110 / 2026-07-27.'),
    (v_machine_id, '17', 69, '231', 'Irska kava 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 4, 17, true, 'Import z realneho planogramu 110 / 2026-07-27.')
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

  -- Touch 21,5 uses 250 ml cups physically; route all cup recipe consumption to Z8.
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
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro telemetrii kavy TID 592148. Import z Excel planogramu 2026-07-27. Counter baseline se nastavi az prvnim DEXem.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();
end $$;

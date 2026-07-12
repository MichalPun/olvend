-- Import real planogram from: Planogram [85] Luce X2 I_E-2026-07-08.xlsx
-- Machine: DB id 65, VendSoft evidence 85, TID/DeviceID 602226.
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy VendSoft code 5.

do $$
declare
  v_machine_id bigint := 65;
begin
  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '602226', true, 'TID 602226 pro Luce X2 I/E / automat 85.'),
    (v_machine_id, 'GP', '602226', true, 'TID 602226 pro Luce X2 I/E / automat 85.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true, note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Tris 1 kg', 3000, 2460, 'g', 1000, 'g', 1000, 1, true, 'Kód ve VendSoft exportu: 5; skladově používáme Barbera Tris 1 kg / SKU 201.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 2118, 'g', 1500, 'g', 1500, 2, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 2000, 431, 'g', 1000, 'g', 1000, 3, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA ZETA 1 kg', 2000, 1100, 'g', 1000, 'g', 1000, 4, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z5', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1000, 614, 'g', 500, 'g', 500, 5, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z6', 110, '46', 'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g', 2000, 972, 'g', 1000, 'g', 1000, 6, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z7', 109, '49', 'oVe FRESH DRINK LEMON 1 kg', 3000, 2964, 'g', 1000, 'g', 1000, 7, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z8', 78, '45', 'Kelímek 180 ml (50 ks)', 400, 257, 'ks', 50, 'ks', 50, 8, true, 'Import z reálného planogramu 85 / 2026-07-08. Balení skladově po 50 ks.'),
    (v_machine_id, 'Z9', 80, '53', 'Kelímek 300 ml (50 ks)', 350, 270, 'ks', 50, 'ks', 50, 9, true, 'Import z reálného planogramu 85 / 2026-07-08.'),
    (v_machine_id, 'Z10', 136, '88', 'VÍČKO HUHTAMAKI PLAST ČERNÉ 300ml', 100, 99, 'ks', 100, 'ks', 100, 10, true, 'Import z reálného planogramu 85 / 2026-07-08.')
  on conflict (machine_id, container_code) do update set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 140, '239', 'Černá káva 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 10, 1, 4, 1, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 301.'),
    (v_machine_id, '2', 31, '215', 'Bílá káva 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 17, 1, 3, 2, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 319.'),
    (v_machine_id, '3', 36, '222', 'Cappuccino 180 ml I NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 35, 1, 2, 3, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 214.'),
    (v_machine_id, '4', 68, '230', 'Irish Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 3, 1, 1, 4, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 284.'),
    (v_machine_id, '5', 71, '233', 'Kakaový nápoj 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 2, 2, 4, 5, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 235.'),
    (v_machine_id, '6', 73, '234', 'Kakaový nápoj Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 10, 2, 3, 6, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 143.'),
    (v_machine_id, '7', 69, '231', 'Irská káva 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 10, 2, 2, 7, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 424.'),
    (v_machine_id, '8', 129, '250', 'Tea 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 2, 2, 1, 8, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 129.'),
    (v_machine_id, '9', 58, '224', 'Espresso NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 8, 3, 4, 9, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 357.'),
    (v_machine_id, '10', 54, '225', 'Espresso Bílé NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 3, 10, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 16.'),
    (v_machine_id, '11', 35, '221', 'CAPPUCCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 28, 3, 2, 11, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 1073.'),
    (v_machine_id, '12', 88, '241', 'LATTE MACCHIATO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 1, 12, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 54.'),
    (v_machine_id, '13', 55, '226', 'Espresso Lungo 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 9, 4, 4, 13, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 136.'),
    (v_machine_id, '14', 56, '227', 'Espresso Lungo bílé 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 9, 4, 3, 14, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 63.'),
    (v_machine_id, '15', 95, '244', 'MOCCACCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 2, 15, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 393.'),
    (v_machine_id, '16', 59, '228', 'ESPRESSO S KAKAOVÝM NÁPOJEM NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 1, 16, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 10.'),
    (v_machine_id, '17', 141, '240', 'Černá káva 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 4, 17, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 129.'),
    (v_machine_id, '18', 32, '216', 'Bílá káva 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 20, 5, 3, 18, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 509.'),
    (v_machine_id, '19', 37, '223', 'Cappuccino 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 22, 5, 2, 19, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 218.'),
    (v_machine_id, '20', 67, '229', 'Irish Cappuccino 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 23, 5, 1, 20, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 427.'),
    (v_machine_id, '21', 74, '235', 'Kakaový nápoj Cream 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 11, 6, 4, 21, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 93.'),
    (v_machine_id, '22', 130, '251', 'Tea 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 3, 22, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 127.'),
    (v_machine_id, '23', 97, '246', 'MOCCACCINO 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, 4, 6, 2, 23, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 99.'),
    (v_machine_id, '24', 90, '243', 'LATTE MACCHIATO 300 ml NEW', 17, 17, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 1, 24, true, 'Import z reálného planogramu 85 / 2026-07-08. Poslední hodnota counteru: 178.')
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

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlový slot pro telemetrii kávy TID 602226. Import z Excel planogramu 2026-07-08.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();

  insert into public.telemetry_planogram_counters (provider, machine_id, planogram_slot_id, selection_code, last_total_count, last_event_at)
  select provider.provider, v_machine_id, slot.id, values_table.selection_code, values_table.last_total_count, now()
  from (values
    ('1', 301),
    ('2', 319),
    ('3', 214),
    ('4', 284),
    ('5', 235),
    ('6', 143),
    ('7', 424),
    ('8', 129),
    ('9', 357),
    ('10', 16),
    ('11', 1073),
    ('12', 54),
    ('13', 136),
    ('14', 63),
    ('15', 393),
    ('16', 10),
    ('17', 129),
    ('18', 509),
    ('19', 218),
    ('20', 427),
    ('21', 93),
    ('22', 127),
    ('23', 99),
    ('24', 178)
  ) as values_table(selection_code, last_total_count)
  join public.machine_planogram_slots slot on slot.machine_id = v_machine_id and slot.slot_code = values_table.selection_code
  cross join (values ('IMA'), ('GP')) as provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update set last_total_count=excluded.last_total_count, last_event_at=excluded.last_event_at, updated_at=now();
end $$;

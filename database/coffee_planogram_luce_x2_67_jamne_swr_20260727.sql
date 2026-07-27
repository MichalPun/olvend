-- Import real planogram from: Planogram [67] Luce X2 I_E-2026-07-27.xlsx
-- Machine: DB id 50, VendSoft evidence 67. TID/DeviceID is intentionally not linked yet.
-- Location: Jamne - SWR (location_id 29).
-- Z1 is intentionally mapped to Barbera Tris SKU 201; the Excel still carries legacy Elite code 5.
-- Excel button codes 263 and 269 are stale; mapped by product name to catalog SKUs 267 and 268.

do $$
declare
  v_machine_id bigint := 50;
begin
  update public.machines
  set
    location_id = 29,
    name = 'Luce X2 I/E',
    brand = 'Rheavendors',
    note = 'Import z VendSoft exportu; puvodni kod 67; lokalita Jamne - SWR. Telemetry ID zatim nepotvrzeno; historicka hodnota 592144 zustava vyhrazena pro automat 117. Zdroj planogramu 2026-07-27.'
  where id = v_machine_id;

  update public.machine_external_links
  set
    telemetry_enabled = false,
    note = 'Vypnuto pri importu planogramu 67 / Jamne - SWR; TID neni potvrzene a 592144 patri automatu 117.',
    updated_at = now()
  where machine_id = v_machine_id;

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;
  delete from public.machine_coffee_recipe_items where machine_id = v_machine_id;
  delete from public.telemetry_planogram_counters where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active, note) values
    (v_machine_id, 'Z1', 26, '201', 'Barbera Tris 1 kg', 3000, 2254, 'g', 1000, 'g', 1000, 1, true, 'Kod ve VendSoft exportu: 5 / Elite; skladove pouzivame Barbera Tris 1 kg / SKU 201. Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z2', 42, '43', 'Cukr Vending 1,5 kg', 3000, 1819, 'g', 1500, 'g', 1500, 2, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z3', 104, '48', 'oVe COFFEE CREAMER WHITE 1 kg', 2000, 0, 'g', 1000, 'g', 1000, 3, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z4', 106, '47', 'oVe DRINK WITH COCOA ZETA 1 kg', 2000, 1360, 'g', 1000, 'g', 1000, 4, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z5', 108, '44', 'oVe FD COFFEE SOPHIA 500g', 1000, 463, 'g', 500, 'g', 500, 5, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z6', 110, '46', 'oVe SMART CAPPUCCINO IRISH CREAM FLAVOUR 1000g', 2000, 1106, 'g', 1000, 'g', 1000, 6, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z7', 143, '262', 'AG PRO Matcha Latte Malina 1 kg', 3000, 2588, 'g', 1000, 'g', 1000, 7, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z8', 78, '45', 'Kelimek 180 ml (50 ks)', 400, 285, 'ks', 50, 'ks', 50, 8, true, 'Import z realneho planogramu 67 / 2026-07-27. V exportu nazev obsahuje 100 ks, skladove doplnujeme po 50 ks.'),
    (v_machine_id, 'Z9', 80, '53', 'Kelimek 300 ml (50 ks)', 350, 197, 'ks', 50, 'ks', 50, 9, true, 'Import z realneho planogramu 67 / 2026-07-27.'),
    (v_machine_id, 'Z10', 136, '88', 'VICKO HUHTAMAKI PLAST CERNE 300ml', 100, 100, 'ks', 100, 'ks', 100, 10, true, 'Import z realneho planogramu 67 / 2026-07-27.')
  on conflict (machine_id, container_code) do update
  set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, capacity_quantity=excluded.capacity_quantity, current_quantity=excluded.current_quantity, unit=excluded.unit, refill_package_quantity=excluded.refill_package_quantity, refill_package_unit=excluded.refill_package_unit, min_refill_quantity=excluded.min_refill_quantity, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_buttons (machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, last_counter, grid_column, grid_row_from_bottom, sort_order, active, note) values
    (v_machine_id, '1', 140, '239', 'Cerna kava 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 4, 1, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 3.'),
    (v_machine_id, '2', 31, '215', 'Bila kava 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 3, 2, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 9.'),
    (v_machine_id, '3', 36, '222', 'Cappuccino 180 ml I NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 2, 3, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 10.'),
    (v_machine_id, '4', 68, '230', 'Irish Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 1, 1, 4, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 2.'),
    (v_machine_id, '5', 71, '233', 'Kakaovy napoj 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 4, 5, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 6.'),
    (v_machine_id, '6', 73, '234', 'Kakaovy napoj Cream 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 3, 6, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 7.'),
    (v_machine_id, '7', 75, '236', 'KAKAOVY NAPOJ DE LUXE 180 ml NEW', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 2, 7, true, 'Import z realneho planogramu 67 / 2026-07-27. Receptura v katalogu obsahuje i SKU 51 / white choc, ale automat v exportu nema odpovidajici zasobnik. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 2.'),
    (v_machine_id, '8', 147, '267', 'Matcha Latte Malina 180 ml', 10, 10, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 2, 1, 8, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel kod 263 je mapovany podle nazvu na katalogove SKU 267. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 1.'),
    (v_machine_id, '9', 58, '224', 'Espresso NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 4, 9, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 13.'),
    (v_machine_id, '10', 54, '225', 'Espresso Bile NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 3, 10, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 6.'),
    (v_machine_id, '11', 35, '221', 'CAPPUCCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 2, 11, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 6.'),
    (v_machine_id, '12', 88, '241', 'LATTE MACCHIATO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 3, 1, 12, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 22.'),
    (v_machine_id, '13', 55, '226', 'Espresso Lungo 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 4, 13, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 13.'),
    (v_machine_id, '14', 56, '227', 'Espresso Lungo bile 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 3, 14, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 11.'),
    (v_machine_id, '15', 95, '244', 'MOCCACCINO (E) 180 ml NEW', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 2, 15, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 2.'),
    (v_machine_id, '16', 145, '265', 'Espresso Matcha Latte 180 ml', 12, 12, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 4, 1, 16, true, 'Import z realneho planogramu 67 / 2026-07-27. Katalogove SKU 265 je vedene jako Espresso Matcha Latte Malina 250 ml, v exportu nazev 180 ml. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 2.'),
    (v_machine_id, '17', 141, '240', 'Cerna kava 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 4, 17, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 11.'),
    (v_machine_id, '18', 32, '216', 'Bila kava 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 3, 18, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 16.'),
    (v_machine_id, '19', 37, '223', 'Cappuccino 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 2, 19, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 4.'),
    (v_machine_id, '20', 67, '229', 'Irish Cappuccino 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 5, 1, 20, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 25.'),
    (v_machine_id, '21', 72, '232', 'Kakaovy napoj 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 4, 21, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 4.'),
    (v_machine_id, '22', 148, '268', 'Matcha Latte Malina 300 ml', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 3, 22, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel kod 269 je mapovany podle nazvu na katalogove SKU 268. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 8.'),
    (v_machine_id, '23', 97, '246', 'MOCCACCINO 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 2, 23, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 4.'),
    (v_machine_id, '24', 90, '243', 'LATTE MACCHIATO 300 ml NEW', 15, 15, 'none', 0, null, false, null, null, null, null, 'exact', null, null, null, 6, 1, 24, true, 'Import z realneho planogramu 67 / 2026-07-27. Excel nema posledni hodnotu counteru; baseline nastavi prvni DEX. VendSoft prodeje v exportu: 81.')
  on conflict (machine_id, selection_code) do update
  set product_id=excluded.product_id, product_sku=excluded.product_sku, product_name=excluded.product_name, sale_price_czk=excluded.sale_price_czk, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, last_counter=excluded.last_counter, grid_column=excluded.grid_column, grid_row_from_bottom=excluded.grid_row_from_bottom, sort_order=excluded.sort_order, active=excluded.active, note=excluded.note, updated_at=now();

  insert into public.machine_coffee_recipe_items (machine_id, coffee_button_id, coffee_container_id, product_id, container_code, ingredient_name, quantity_per_vend, unit, sort_order, active)
  select
    v_machine_id,
    button.id,
    container.id,
    recipe_item.product_id,
    container.container_code,
    coalesce(container.product_name, ingredient.name),
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
  left join public.products ingredient on ingredient.id = recipe_item.product_id
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
  join public.machine_coffee_containers container on container.machine_id = button.machine_id and container.container_code = 'Z8'
  where item.machine_id = v_machine_id
    and item.coffee_button_id = button.id
    and button.machine_id = v_machine_id
    and button.selection_code in ('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16')
    and item.product_id in (78,79,80);

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
    and button.selection_code in ('17','18','19','20','21','22','23','24')
    and item.product_id in (78,79,80);

  insert into public.machine_planogram_slots (machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk, capacity_units, current_units, fill_percent, active, sort_order, telemetry_key, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, note)
  select v_machine_id, selection_code, product_name, product_sku, sale_price_czk, sale_price_czk, null, null, null, active, sort_order, selection_code, customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner, settlement_billing_enabled, settlement_note, planned_product_name, planned_product_sku, planned_price_czk, substitution_policy, allowed_substitutes, operator_instruction, 'Zrcadlovy slot pro telemetrii kavy automatu 67 / Jamne - SWR. TID/DeviceID zatim neni v OLVENDu potvrzene; Excel nemel posledni hodnoty counteru, prvni DEX nastavi baseline.'
  from public.machine_coffee_buttons
  where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update
  set product_name=excluded.product_name, product_sku=excluded.product_sku, price_czk=excluded.price_czk, dex_price_czk=excluded.dex_price_czk, active=excluded.active, sort_order=excluded.sort_order, telemetry_key=excluded.telemetry_key, customer_price_czk=excluded.customer_price_czk, settlement_type=excluded.settlement_type, settlement_amount_czk=excluded.settlement_amount_czk, settlement_partner=excluded.settlement_partner, settlement_billing_enabled=excluded.settlement_billing_enabled, settlement_note=excluded.settlement_note, planned_product_name=excluded.planned_product_name, planned_product_sku=excluded.planned_product_sku, planned_price_czk=excluded.planned_price_czk, substitution_policy=excluded.substitution_policy, allowed_substitutes=excluded.allowed_substitutes, operator_instruction=excluded.operator_instruction, note=excluded.note, updated_at=now();
end $$;

select
  m.id as machine_id,
  m.evidence_number,
  m.name,
  l.name as location_name,
  l.city,
  (select count(*) from public.machine_external_links mel where mel.machine_id = m.id and mel.telemetry_enabled = true) as active_telemetry_links,
  (select count(*) from public.machine_coffee_containers c where c.machine_id = m.id and c.active = true) as active_containers,
  (select count(*) from public.machine_coffee_buttons b where b.machine_id = m.id and b.active = true) as active_buttons,
  (select count(*) from public.machine_planogram_slots s where s.machine_id = m.id and s.active = true) as active_slots,
  (select count(*) from public.machine_coffee_recipe_items ri where ri.machine_id = m.id and ri.active = true) as active_recipe_items,
  (select count(*) from public.machine_coffee_recipe_items ri where ri.machine_id = m.id and ri.active = true and ri.coffee_container_id is null) as recipe_items_without_container,
  (select count(*) from public.telemetry_planogram_counters tc where tc.machine_id = m.id) as counter_baselines
from public.machines m
left join public.locations l on l.id = m.location_id
where m.id = 50;

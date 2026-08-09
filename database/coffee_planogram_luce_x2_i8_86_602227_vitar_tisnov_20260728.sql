-- Planogram [86] Luce X2 I8-2026-07-28.xlsx
-- Machine DB id 66, evidence 86, TID 602227, Vitar Tišnov location_id 60.
-- Instant X2 I8: 24 physical selections plus aggregate telemetry selection 0.
-- Selection 11 source SKU 238 is replaced by confirmed Kakaový nápoj Cream SKU 234.

do $$
declare
  v_machine_id bigint := 66;
begin
  update public.machines
  set location_id = 60, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I8', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; Vitar Tišnov; TID 602227; instantní X2 I8; fyzické volby 1–24; souhrnná telemetrie volbou 0; volba 11 nahrazena SKU 234.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '602227', true, 'TID 602227 pro Luce X2 I8 / automat 86 / Vitar Tišnov.'),
    (v_machine_id, 'GP', '602227', true, 'TID 602227 pro Luce X2 I8 / automat 86 / Vitar Tišnov.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true,
      note = excluded.note, updated_at = now();

  update public.machine_coffee_containers set active = false where machine_id = v_machine_id;
  update public.machine_coffee_buttons set active = false where machine_id = v_machine_id;
  update public.machine_planogram_slots set active = false where machine_id = v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id, container_code, product_id, product_sku, product_name,
    capacity_quantity, current_quantity, unit, refill_package_quantity,
    refill_package_unit, min_refill_quantity, sort_order, active, note
  )
  select
    v_machine_id, d.container_code, p.id, p.sku, p.name,
    d.capacity_quantity, d.current_quantity, d.unit,
    d.package_quantity, d.package_unit, d.package_quantity,
    d.sort_order, true,
    'Import planogramu 86 / 2026-07-28.'
      || case when d.container_code = 'Z9'
        then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1', '44', 1000::numeric, 920::numeric,'g', 500::numeric,'g',1),
    ('Z2', '43', 3000::numeric,2848::numeric,'g',1500::numeric,'g',2),
    ('Z3', '48', 3000::numeric,2660::numeric,'g',1000::numeric,'g',3),
    ('Z4', '47', 3000::numeric,2872::numeric,'g',1000::numeric,'g',4),
    ('Z5', '51', 3000::numeric,2999::numeric,'g',1000::numeric,'g',5),
    ('Z6', '183', 100::numeric, 100::numeric,'ks',100::numeric,'ks',6),
    ('Z7', '46', 3000::numeric,2680::numeric,'g',1000::numeric,'g',7),
    ('Z8', '49', 3000::numeric,2880::numeric,'g',1000::numeric,'g',8),
    ('Z9', '45',  400::numeric, 360::numeric,'ks', 50::numeric,'ks',9),
    ('Z10','53',  350::numeric, 349::numeric,'ks', 50::numeric,'ks',10),
    ('Z11','88',  100::numeric,  99::numeric,'ks',100::numeric,'ks',11)
  ) d(
    container_code, product_sku, capacity_quantity, current_quantity,
    unit, package_quantity, package_unit, sort_order
  )
  join public.products p on p.sku = d.product_sku
  on conflict (machine_id, container_code) do update
  set product_id = excluded.product_id, product_sku = excluded.product_sku,
      product_name = excluded.product_name, capacity_quantity = excluded.capacity_quantity,
      current_quantity = excluded.current_quantity, unit = excluded.unit,
      refill_package_quantity = excluded.refill_package_quantity,
      refill_package_unit = excluded.refill_package_unit,
      min_refill_quantity = excluded.min_refill_quantity,
      sort_order = excluded.sort_order, active = true, note = excluded.note,
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
    d.price, d.price, 'none', 0, null, false, null,
    null, null, null, 'exact', null,
    case when d.selection_code = '11'
      then 'Potvrzeno: zdrojové SKU 238 je nahrazeno Kakaový nápoj Cream SKU 234.'
      else null
    end,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 86 / 2026-07-28.'
  from (values
    ('1', '239', 5::numeric,      32::integer,1,4, 1),
    ('2', '215', 5::numeric,      86::integer,1,3, 2),
    ('3', '222', 5::numeric,     133::integer,1,2, 3),
    ('4', '230', 5::numeric,     153::integer,1,1, 4),
    ('5', '219', 5::numeric,     245::integer,2,4, 5),
    ('6', '217', 5::numeric,     194::integer,2,3, 6),
    ('7', '247', 5::numeric,  134766::integer,2,2, 7),
    ('8', '231', 5::numeric,     188::integer,2,1, 8),
    ('9', '233', 5::numeric, 8022352::integer,3,4, 9),
    ('10','234', 5::numeric,      52::integer,3,3,10),
    ('11','234', 5::numeric,     561::integer,3,2,11),
    ('12','236', 8::numeric,      55::integer,3,1,12),
    ('13','240',12::numeric,      10::integer,4,4,13),
    ('14','216',12::numeric,       7::integer,4,3,14),
    ('15','223',12::numeric, 8022351::integer,4,2,15),
    ('16','251', 5::numeric,      37::integer,4,1,16),
    ('17','235',12::numeric,  134550::integer,5,4,17),
    ('18','237',17::numeric,      18::integer,5,3,18),
    ('19','218',12::numeric,  233747::integer,5,2,19),
    ('20','251',12::numeric,      53::integer,5,1,20),
    ('21','220',12::numeric,      99::integer,6,4,21),
    ('22','243',12::numeric,     253::integer,6,3,22),
    ('23','246',12::numeric,     370::integer,6,2,23),
    ('24','229',12::numeric,      14::integer,6,1,24)
  ) d(
    selection_code, product_sku, price, last_counter,
    grid_column, grid_row_from_bottom, sort_order
  )
  join public.products p on p.sku = d.product_sku
  on conflict (machine_id, selection_code) do update
  set product_id = excluded.product_id, product_sku = excluded.product_sku,
      product_name = excluded.product_name, sale_price_czk = excluded.sale_price_czk,
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
      last_counter = excluded.last_counter, grid_column = excluded.grid_column,
      grid_row_from_bottom = excluded.grid_row_from_bottom,
      sort_order = excluded.sort_order, active = true, note = excluded.note,
      updated_at = now();

  delete from public.machine_coffee_recipe_items where machine_id = v_machine_id;

  insert into public.machine_coffee_recipe_items (
    machine_id, coffee_button_id, coffee_container_id, product_id,
    container_code, ingredient_name, quantity_per_vend, unit, sort_order, active
  )
  select
    v_machine_id, b.id, c.id, ri.product_id,
    c.container_code, c.product_name, ri.quantity, ri.unit, ri.id, true
  from public.machine_coffee_buttons b
  join lateral (
    select r.* from public.recipes r
    where r.machine_type = 'product_catalog'
      and r.selection_code = 'product:' || b.product_id::text
    order by (r.sale_price = b.sale_price_czk) desc nulls last, r.id desc
    limit 1
  ) r on true
  join public.recipe_items ri on ri.recipe_id = r.id
  left join public.machine_coffee_containers c
    on c.machine_id = v_machine_id and c.product_id = ri.product_id
  where b.machine_id = v_machine_id and b.active;

  update public.machine_coffee_recipe_items i
  set coffee_container_id = c.id, product_id = c.product_id,
      container_code = c.container_code, ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z9'
  where i.machine_id = v_machine_id and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id and b.sort_order <= 12
    and i.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    );

  update public.machine_coffee_recipe_items i
  set coffee_container_id = c.id, product_id = c.product_id,
      container_code = c.container_code, ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z10'
  where i.machine_id = v_machine_id and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id and b.sort_order >= 13
    and i.product_id in (
      select id from public.products
      where sku in ('53','79') or lower(name) like 'kelímek 300 ml%'
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
    v_machine_id, selection_code, product_name, product_sku,
    sale_price_czk, sale_price_czk, null, null, null, active,
    sort_order, selection_code, customer_price_czk,
    settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction,
    'Fyzický X2 I8 slot; planogram 2026-07-28 / TID 602227 / Vitar Tišnov.'
  from public.machine_coffee_buttons where machine_id = v_machine_id
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name, product_sku = excluded.product_sku,
      price_czk = excluded.price_czk, dex_price_czk = excluded.dex_price_czk,
      active = excluded.active, sort_order = excluded.sort_order,
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
      note = excluded.note, updated_at = now();

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    active, sort_order, telemetry_key, customer_price_czk,
    settlement_type, settlement_amount_czk, settlement_billing_enabled,
    settlement_note, substitution_policy, operator_instruction, note
  )
  values (
    v_machine_id, '0', 'Telemetrie prodej káva', '252', 12, 12,
    true, 0, '0', 12, 'none', 0, false,
    'Souhrnný telemetrický kanál bez konkrétní receptury.',
    'exact', 'Neodečítat recepturu podle volby 0.',
    'Agregační slot X2 I8 / TID 602227 / Vitar Tišnov.'
  )
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name, product_sku = excluded.product_sku,
      price_czk = excluded.price_czk, dex_price_czk = excluded.dex_price_czk,
      active = true, sort_order = excluded.sort_order,
      telemetry_key = excluded.telemetry_key,
      customer_price_czk = excluded.customer_price_czk,
      settlement_type = excluded.settlement_type,
      settlement_amount_czk = excluded.settlement_amount_czk,
      settlement_billing_enabled = excluded.settlement_billing_enabled,
      settlement_note = excluded.settlement_note,
      substitution_policy = excluded.substitution_policy,
      operator_instruction = excluded.operator_instruction,
      note = excluded.note, updated_at = now();

  insert into public.telemetry_planogram_counters (
    provider, machine_id, planogram_slot_id, selection_code,
    last_total_count, last_event_at
  )
  select provider.provider, v_machine_id, slot.id,
         counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',32),('2',86),('3',133),('4',153),('5',245),('6',194),
    ('7',134766),('8',188),('9',8022352),('10',52),('11',561),('12',55),
    ('13',10),('14',7),('15',8022351),('16',37),('17',134550),('18',18),
    ('19',233747),('20',53),('21',99),('22',253),('23',370),('24',14)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

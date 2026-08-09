-- Planogram [93] Luce X2 I-2026-07-28.xlsx
-- Machine DB id 73, evidence 93, TID 604314, Sportovní hala Krásné Pole location_id 49.
-- Instant X2: physical selections 1-24, no aggregate selection 0.

do $$
declare
  v_machine_id bigint := 73;
begin
  update public.machines
  set location_id = 49, machine_type = 'Coffee', brand = 'Rheavendors',
      name = 'Luce X2 I', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; Sportovní hala Krásné Pole; TID 604314; instantní X2; plná telemetrie voleb 1–24.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '604314', true, 'TID 604314 pro automat 93 / Sportovní hala Krásné Pole.'),
    (v_machine_id, 'GP', '604314', true, 'TID 604314 pro automat 93 / Sportovní hala Krásné Pole.')
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
    'Import planogramu 93 / 2026-07-28.'
      || case when d.container_code = 'Z9'
        then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1', '44', 1000::numeric, 978::numeric,'g', 500::numeric,'g',1),
    ('Z2', '43', 3000::numeric,2965::numeric,'g',1500::numeric,'g',2),
    ('Z3', '48', 3000::numeric,2931::numeric,'g',1000::numeric,'g',3),
    ('Z4', '47', 3000::numeric,2632::numeric,'g',1000::numeric,'g',4),
    ('Z5', '51', 3000::numeric,2638::numeric,'g',1000::numeric,'g',5),
    ('Z6', '197',3000::numeric,2944::numeric,'g',1000::numeric,'g',6),
    ('Z7', '46', 3000::numeric,2999::numeric,'g',1000::numeric,'g',7),
    ('Z8', '49', 3000::numeric,3000::numeric,'g',1000::numeric,'g',8),
    ('Z9', '45',  400::numeric, 393::numeric,'ks', 50::numeric,'ks',9),
    ('Z10','53',  350::numeric, 330::numeric,'ks', 50::numeric,'ks',10)
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
    null, null, null, 'exact', null, null,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 93 / 2026-07-28.'
  from (values
    ('1', '239',25::numeric,16::integer,1,4,1),
    ('2', '215',25::numeric,12::integer,1,3,2),
    ('3', '222',25::numeric,28::integer,1,2,3),
    ('4', '245',25::numeric, 7::integer,1,1,4),
    ('5', '242',25::numeric,18::integer,2,4,5),
    ('6', '219',25::numeric, 4::integer,2,3,6),
    ('7', '233',25::numeric,14::integer,2,2,7),
    ('8', '236',25::numeric,14::integer,2,1,8),
    ('9', '230',25::numeric,27::integer,3,4,9),
    ('10','248',25::numeric,24::integer,3,3,10),
    ('11','250',25::numeric, 8::integer,3,2,11),
    ('12','217',25::numeric,33::integer,3,1,12),
    ('13','240',35::numeric,23::integer,4,4,13),
    ('14','216',35::numeric,18::integer,4,3,14),
    ('15','223',35::numeric,37::integer,4,2,15),
    ('16','246',35::numeric, 4::integer,4,1,16),
    ('17','243',35::numeric,56::integer,5,4,17),
    ('18','220',35::numeric,18::integer,5,3,18),
    ('19','232',35::numeric,15::integer,5,2,19),
    ('20','237',35::numeric,34::integer,5,1,20),
    ('21','229',35::numeric,69::integer,6,4,21),
    ('22','249',35::numeric,46::integer,6,3,22),
    ('23','251',35::numeric,85::integer,6,2,23),
    ('24','218',35::numeric,29::integer,6,1,24)
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
    active, sort_order, telemetry_key, customer_price_czk, settlement_type,
    settlement_amount_czk, settlement_partner, settlement_billing_enabled,
    settlement_note, planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction, note
  )
  select
    v_machine_id, selection_code, product_name, product_sku,
    sale_price_czk, sale_price_czk, active, sort_order, selection_code,
    customer_price_czk, settlement_type, settlement_amount_czk,
    settlement_partner, settlement_billing_enabled, settlement_note,
    planned_product_name, planned_product_sku, planned_price_czk,
    substitution_policy, allowed_substitutes, operator_instruction,
    'Instantní X2 slot; planogram 2026-07-28 / TID 604314 / Krásné Pole.'
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

  insert into public.telemetry_planogram_counters (
    provider, machine_id, planogram_slot_id, selection_code,
    last_total_count, last_event_at
  )
  select provider.provider, v_machine_id, slot.id,
         counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',16),('2',12),('3',28),('4',7),('5',18),('6',4),
    ('7',14),('8',14),('9',27),('10',24),('11',8),('12',33),
    ('13',23),('14',18),('15',37),('16',4),('17',56),('18',18),
    ('19',15),('20',34),('21',69),('22',46),('23',85),('24',29)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

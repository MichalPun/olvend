-- Planogram [76] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 56, evidence 76, TID 598500, OSRAM location_id 16.
-- X2 uses full telemetry for selections 1-24; no aggregate selection 0.
-- Legacy Elite / code 5 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 56;
begin
  update public.machines
  set location_id = 16,
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce X2 I/E',
      sales_tracking_mode = 'telemetry',
      note = concat_ws(
        ' ', nullif(note, ''),
        'Planogram 2026-07-28; OSRAM Česká republika s.r.o.; TID 598500; plná telemetrie voleb 1–24.'
      )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '598500', true, 'TID 598500 pro Luce X2 I/E / automat 76 / OSRAM.'),
    (v_machine_id, 'GP', '598500', true, 'TID 598500 pro Luce X2 I/E / automat 76 / OSRAM.')
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
    'Import planogramu 76 / 2026-07-28.'
      || case
        when d.container_code = 'Z1'
          then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        when d.container_code = 'Z8'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1', '201',3000::numeric,2880::numeric,'g',1000::numeric,'g',1),
    ('Z2', '43', 3000::numeric,2887::numeric,'g',1500::numeric,'g',2),
    ('Z3', '48', 2000::numeric,1677::numeric,'g',1000::numeric,'g',3),
    ('Z4', '47', 2000::numeric,1898::numeric,'g',1000::numeric,'g',4),
    ('Z5', '44', 1000::numeric, 967::numeric,'g', 500::numeric,'g',5),
    ('Z6', '46', 2000::numeric,1650::numeric,'g',1000::numeric,'g',6),
    ('Z7', '49', 3000::numeric,3000::numeric,'g',1000::numeric,'g',7),
    ('Z8', '45',  400::numeric, 366::numeric,'ks', 50::numeric,'ks',8),
    ('Z9', '53',  350::numeric, 344::numeric,'ks', 50::numeric,'ks',9),
    ('Z10','88',  100::numeric,  99::numeric,'ks',100::numeric,'ks',10),
    ('Z11','183', 100::numeric,  99::numeric,'ks',100::numeric,'ks',11)
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
    d.price, d.price, 'none', 0, null, false, null,
    null, null, null, 'exact', null, null,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 76 / 2026-07-28.'
  from (values
    ('1', '239',10::numeric, 17::integer,1,4, 1),
    ('2', '215',10::numeric,161::integer,1,3, 2),
    ('3', '222',10::numeric, 49::integer,1,2, 3),
    ('4', '230',10::numeric,725::integer,1,1, 4),
    ('5', '233',10::numeric, 22::integer,2,4, 5),
    ('6', '234',10::numeric, 43::integer,2,3, 6),
    ('7', '231',10::numeric,897::integer,2,2, 7),
    ('8', '250',10::numeric,558::integer,2,1, 8),
    ('9', '224',12::numeric, 13::integer,3,4, 9),
    ('10','225',12::numeric,168::integer,3,3,10),
    ('11','221',12::numeric,145::integer,3,2,11),
    ('12','241',12::numeric,775::integer,3,1,12),
    ('13','226',12::numeric,159::integer,4,4,13),
    ('14','227',12::numeric,659::integer,4,3,14),
    ('15','244',12::numeric,236::integer,4,2,15),
    ('16','228',12::numeric, 21::integer,4,1,16),
    ('17','240',17::numeric, 24::integer,5,4,17),
    ('18','216',17::numeric,148::integer,5,3,18),
    ('19','223',17::numeric, 32::integer,5,2,19),
    ('20','229',17::numeric, 73::integer,5,1,20),
    ('21','232',17::numeric,  4::integer,6,4,21),
    ('22','251',17::numeric, 12::integer,6,3,22),
    ('23','246',17::numeric,151::integer,6,2,23),
    ('24','243',17::numeric,429::integer,6,1,24)
  ) d(
    selection_code, product_sku, price, last_counter,
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
    v_machine_id, b.id, c.id, ri.product_id,
    c.container_code, c.product_name, ri.quantity, ri.unit, ri.id, true
  from public.machine_coffee_buttons b
  join lateral (
    select r.*
    from public.recipes r
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
  set coffee_container_id = c.id,
      product_id = c.product_id,
      container_code = c.container_code,
      ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z8'
  where i.machine_id = v_machine_id
    and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id
    and b.selection_code in (
      '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16'
    )
    and i.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    );

  update public.machine_coffee_recipe_items i
  set coffee_container_id = c.id,
      product_id = c.product_id,
      container_code = c.container_code,
      ingredient_name = c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id = b.machine_id and c.container_code = 'Z9'
  where i.machine_id = v_machine_id
    and i.coffee_button_id = b.id
    and b.machine_id = v_machine_id
    and b.selection_code in ('17','18','19','20','21','22','23','24')
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
    'Zrcadlový X2 slot; planogram 2026-07-28 / TID 598500 / OSRAM.'
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

  insert into public.telemetry_planogram_counters (
    provider, machine_id, planogram_slot_id, selection_code,
    last_total_count, last_event_at
  )
  select provider.provider, v_machine_id, slot.id,
         counter.selection_code, counter.last_total_count, now()
  from (values
    ('1',17),('2',161),('3',49),('4',725),('5',22),('6',43),
    ('7',897),('8',558),('9',13),('10',168),('11',145),('12',775),
    ('13',159),('14',659),('15',236),('16',21),('17',24),('18',148),
    ('19',32),('20',73),('21',4),('22',12),('23',151),('24',429)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

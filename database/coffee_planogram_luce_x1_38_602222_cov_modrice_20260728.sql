-- Planogram [38] Luce X1 I_E-2026-07-28.xlsx
-- Machine DB id 32, evidence 38, TID 602222, BVK ČOV Modřice location_id 43.
-- X1 aggregate telemetry uses selection 0; physical buttons are selections 1-16.
-- Elite / code 5 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 32;
begin
  update public.machines
  set location_id = 43,
      machine_type = 'Coffee',
      brand = 'Rheavendors',
      name = 'Luce X1 I/E',
      sales_tracking_mode = 'telemetry',
      note = concat_ws(
        ' ', nullif(note, ''),
        'Planogram 2026-07-28; BVK ČOV Modřice; TID 602222; souhrnná X1 telemetrie volbou 0.'
      )
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '602222', true, 'TID 602222 pro Luce X1 I/E / automat 38 / BVK ČOV Modřice.'),
    (v_machine_id, 'GP', '602222', true, 'TID 602222 pro Luce X1 I/E / automat 38 / BVK ČOV Modřice.')
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
    'Import planogramu 38 / 2026-07-28.'
      || case
        when d.container_code = 'Z1'
          then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        when d.container_code = 'Z7'
          then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1','201',2000::numeric,2000::numeric,'g',1000::numeric,'g',1),
    ('Z2','43', 3000::numeric,3000::numeric,'g',1500::numeric,'g',2),
    ('Z3','48', 2000::numeric,2000::numeric,'g',1000::numeric,'g',3),
    ('Z4','47', 2000::numeric,2000::numeric,'g',1000::numeric,'g',4),
    ('Z5','46', 2000::numeric,2000::numeric,'g',1000::numeric,'g',5),
    ('Z6','44', 1000::numeric,1000::numeric,'g', 500::numeric,'g',6),
    ('Z7','45',  400::numeric, 399::numeric,'ks',  50::numeric,'ks',7)
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
    'Import planogramu 38 / 2026-07-28.'
  from (values
    ('1', '224',16::numeric,1177::integer,1,4, 1),
    ('2', '226',16::numeric, 974::integer,1,3, 2),
    ('3', '225',16::numeric, 890::integer,1,2, 3),
    ('4', '227',16::numeric, 730::integer,1,1, 4),
    ('5', '241',16::numeric,1527::integer,2,4, 5),
    ('6', '228',16::numeric,  93::integer,2,3, 6),
    ('7', '221',16::numeric,1439::integer,2,2, 7),
    ('8', '244',16::numeric, 462::integer,2,1, 8),
    ('9', '239',14::numeric, 155::integer,3,4, 9),
    ('10','215',14::numeric, 999::integer,3,3,10),
    ('11','222',14::numeric,2628::integer,3,2,11),
    ('12','245',14::numeric, 212::integer,3,1,12),
    ('13','242',14::numeric, 776::integer,4,4,13),
    ('14','230',14::numeric,2847::integer,4,3,14),
    ('15','233',14::numeric, 196::integer,4,2,15),
    ('16','234',14::numeric, 862::integer,4,1,16)
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
  from public.machine_coffee_containers c
  where i.machine_id = v_machine_id
    and i.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    )
    and c.machine_id = v_machine_id
    and c.container_code = 'Z7'
    and c.active;

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
    'Fyzická X1 volba; planogram 2026-07-28 / TID 602222 / BVK ČOV Modřice.'
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

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    capacity_units, current_units, fill_percent, active, sort_order, telemetry_key,
    customer_price_czk, settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note, planned_product_name,
    planned_product_sku, planned_price_czk, substitution_policy,
    allowed_substitutes, operator_instruction, note
  )
  values (
    v_machine_id, '0', 'Telemetrie prodej káva', '252', 10, 10,
    null, null, null, true, 0, '0', 10, 'none', 0, null, false,
    'Souhrnný X1 kanál bez konkrétní volby nápoje.',
    null, null, null, 'exact', null,
    'Souhrnná telemetrie X1: neodečítat recepturu podle volby 0.',
    'Agregační X1 slot TID 602222; bez fyzického tlačítka a receptury.'
  )
  on conflict (machine_id, slot_code) do update
  set product_name = excluded.product_name,
      product_sku = excluded.product_sku,
      price_czk = excluded.price_czk,
      dex_price_czk = excluded.dex_price_czk,
      active = true,
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
    ('1',1177),('2',974),('3',890),('4',730),
    ('5',1527),('6',93),('7',1439),('8',462),
    ('9',155),('10',999),('11',2628),('12',212),
    ('13',776),('14',2847),('15',196),('16',862)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at,
      updated_at = now();
end $$;

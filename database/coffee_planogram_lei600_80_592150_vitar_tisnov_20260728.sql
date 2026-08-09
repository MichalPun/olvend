-- Planogram [80] LEI 600 Touch-2026-07-28.xlsx
-- Machine DB id 60, evidence 80, TID 592150, Vitar Tišnov location_id 60.
-- Full telemetry for selections 1-21; source SKU 238 on selection 21 is replaced by SKU 234.

do $$
declare
  v_machine_id bigint := 60;
begin
  update public.machines
  set location_id = 60, machine_type = 'Coffee', brand = 'Bianchi',
      name = 'LEI 600 Touch', sales_tracking_mode = 'telemetry',
      note = concat_ws(' ', nullif(note, ''),
        'Planogram 2026-07-28; Vitar Tišnov; TID 592150; plná telemetrie voleb 1–21; tlačítko 21 nahrazeno SKU 234.')
  where id = v_machine_id;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '592150', true, 'TID 592150 pro LEI 600 Touch / automat 80 / Vitar Tišnov.'),
    (v_machine_id, 'GP', '592150', true, 'TID 592150 pro LEI 600 Touch / automat 80 / Vitar Tišnov.')
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
    'Import planogramu 80 / 2026-07-28.'
      || case when d.container_code = 'Z1'
        then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
        when d.container_code = 'Z8'
        then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
        else ''
      end
  from (values
    ('Z1','201',3000::numeric,2999::numeric,'g',1000::numeric,'g',1),
    ('Z2','43', 3000::numeric,2999::numeric,'g',1500::numeric,'g',2),
    ('Z3','44', 1000::numeric, 999::numeric,'g', 500::numeric,'g',3),
    ('Z4','51', 2000::numeric,1999::numeric,'g',1000::numeric,'g',4),
    ('Z5','46', 3000::numeric,2999::numeric,'g',1000::numeric,'g',5),
    ('Z6','47', 3000::numeric,2999::numeric,'g',1000::numeric,'g',6),
    ('Z7','48', 3000::numeric,2999::numeric,'g',1000::numeric,'g',7),
    ('Z8','45',  500::numeric, 499::numeric,'ks', 50::numeric,'ks',8)
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
    case when d.selection_code = '21'
      then 'Potvrzeno: zdrojové SKU 238 je nahrazeno Kakaový nápoj Cream SKU 234.'
      else null
    end,
    d.last_counter, d.grid_column, d.grid_row_from_bottom, d.sort_order, true,
    'Import planogramu 80 / 2026-07-28.'
  from (values
    ('1', '224',10::numeric, 604::integer,1,6, 1),
    ('2', '225',10::numeric,1198::integer,1,5, 2),
    ('3', '244',10::numeric,1607::integer,1,4, 3),
    ('4', '226',10::numeric, 867::integer,1,3, 4),
    ('5', '221',10::numeric, 884::integer,1,2, 5),
    ('6', '241',10::numeric, 941::integer,1,1, 6),
    ('7', '239', 5::numeric, 117::integer,2,6, 7),
    ('8', '215', 5::numeric,   0::integer,2,5, 8),
    ('9', '245', 5::numeric,   0::integer,2,4, 9),
    ('10','239', 5::numeric,   0::integer,2,3,10),
    ('11','222', 5::numeric,   0::integer,2,2,11),
    ('12','242', 5::numeric,   0::integer,2,1,12),
    ('13','233', 5::numeric,   0::integer,3,6,13),
    ('14','236', 5::numeric,   0::integer,3,5,14),
    ('15','222', 5::numeric,   0::integer,3,4,15),
    ('16','217', 5::numeric,   0::integer,3,3,16),
    ('17','219', 5::numeric,   0::integer,3,2,17),
    ('18','230', 5::numeric,1048::integer,3,1,18),
    ('19','234', 5::numeric, 117::integer,4,3,19),
    ('20','222', 5::numeric,1662::integer,4,2,20),
    ('21','234', 5::numeric,2207::integer,4,1,21)
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
  from public.machine_coffee_containers c
  where i.machine_id = v_machine_id
    and i.product_id in (
      select id from public.products
      where sku in ('45','79','255')
         or lower(name) like 'kelímek 180 ml%'
         or lower(name) like 'kelímek 250 ml%'
    )
    and c.machine_id = v_machine_id and c.container_code = 'Z8' and c.active;

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
    'LEI 600 Touch slot; planogram 2026-07-28 / TID 592150 / Vitar Tišnov.'
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
    ('1',604),('2',1198),('3',1607),('4',867),('5',884),('6',941),
    ('7',117),('8',0),('9',0),('10',0),('11',0),('12',0),
    ('13',0),('14',0),('15',0),('16',0),('17',0),('18',1048),
    ('19',117),('20',1662),('21',2207)
  ) counter(selection_code, last_total_count)
  join public.machine_planogram_slots slot
    on slot.machine_id = v_machine_id and slot.slot_code = counter.selection_code
  cross join (values ('IMA'),('GP')) provider(provider)
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set last_total_count = excluded.last_total_count,
      last_event_at = excluded.last_event_at, updated_at = now();
end $$;

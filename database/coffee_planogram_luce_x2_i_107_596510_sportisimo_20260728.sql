-- Planogram [107] Luce X2 I-2026-07-28.xlsx
-- Machine DB id 87, evidence 107, TID 596510, Sportisimo location_id 58.
-- Instant X2: selections 1-24, no aggregate selection 0, all prices 0.

do $$
declare
  v_machine_id bigint := 87;
  v_source_machine_id bigint := 73; -- verified matching instant X2 layout
begin
  update public.machines
  set location_id=58,machine_type='Coffee',brand='Rheavendors',
      name='Luce X2 I',sales_tracking_mode='telemetry',
      note=concat_ws(' ',nullif(note,''),
        'Planogram 2026-07-28; Sportisimo; TID 596510; instantní X2; volby 1–24; ceny 0 Kč.')
  where id=v_machine_id;

  insert into public.machine_external_links
    (machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','596510',true,'TID 596510 pro automat 107 / Sportisimo.'),
    (v_machine_id,'GP','596510',true,'TID 596510 pro automat 107 / Sportisimo.')
  on conflict (provider,external_machine_id) do update
  set machine_id=excluded.machine_id,telemetry_enabled=true,note=excluded.note,updated_at=now();

  update public.machine_coffee_containers set active=false where machine_id=v_machine_id;
  update public.machine_coffee_buttons set active=false where machine_id=v_machine_id;
  update public.machine_planogram_slots set active=false where machine_id=v_machine_id;

  insert into public.machine_coffee_containers (
    machine_id,container_code,product_id,product_sku,product_name,
    capacity_quantity,current_quantity,unit,refill_package_quantity,
    refill_package_unit,min_refill_quantity,sort_order,active,note
  )
  select v_machine_id,s.container_code,s.product_id,s.product_sku,s.product_name,
         d.capacity,d.current,s.unit,s.refill_package_quantity,
         s.refill_package_unit,s.min_refill_quantity,s.sort_order,true,
         'Import planogramu 107 / 2026-07-28.'
  from public.machine_coffee_containers s
  join (values
    ('Z1',1500::numeric,1378::numeric),('Z2',3000::numeric,2817::numeric),
    ('Z3',3000::numeric,2482::numeric),('Z4',3000::numeric,2322::numeric),
    ('Z5',3000::numeric,2837::numeric),('Z6',3000::numeric,2808::numeric),
    ('Z7',3000::numeric,2640::numeric),('Z8',3000::numeric,2768::numeric),
    ('Z9',400::numeric,366::numeric),('Z10',350::numeric,299::numeric)
  ) d(code,capacity,current) on d.code=s.container_code
  where s.machine_id=v_source_machine_id and s.active
  on conflict (machine_id,container_code) do update set
    product_id=excluded.product_id,product_sku=excluded.product_sku,
    product_name=excluded.product_name,capacity_quantity=excluded.capacity_quantity,
    current_quantity=excluded.current_quantity,unit=excluded.unit,
    refill_package_quantity=excluded.refill_package_quantity,
    refill_package_unit=excluded.refill_package_unit,
    min_refill_quantity=excluded.min_refill_quantity,sort_order=excluded.sort_order,
    active=true,note=excluded.note,updated_at=now();

  insert into public.machine_coffee_buttons (
    machine_id,selection_code,product_id,product_sku,product_name,
    sale_price_czk,customer_price_czk,settlement_type,settlement_amount_czk,
    settlement_partner,settlement_billing_enabled,settlement_note,
    planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,
    last_counter,grid_column,grid_row_from_bottom,sort_order,active,note
  )
  select v_machine_id,s.selection_code,s.product_id,s.product_sku,s.product_name,
         0,0,'none',0,null,false,null,null,null,null,'exact',null,null,
         41,s.grid_column,s.grid_row_from_bottom,s.sort_order,true,
         'Import planogramu 107 / 2026-07-28.'
  from public.machine_coffee_buttons s
  where s.machine_id=v_source_machine_id and s.active
  on conflict (machine_id,selection_code) do update set
    product_id=excluded.product_id,product_sku=excluded.product_sku,
    product_name=excluded.product_name,sale_price_czk=excluded.sale_price_czk,
    customer_price_czk=excluded.customer_price_czk,
    settlement_type=excluded.settlement_type,
    settlement_amount_czk=excluded.settlement_amount_czk,
    settlement_partner=excluded.settlement_partner,
    settlement_billing_enabled=excluded.settlement_billing_enabled,
    settlement_note=excluded.settlement_note,
    planned_product_name=excluded.planned_product_name,
    planned_product_sku=excluded.planned_product_sku,
    planned_price_czk=excluded.planned_price_czk,
    substitution_policy=excluded.substitution_policy,
    allowed_substitutes=excluded.allowed_substitutes,
    operator_instruction=excluded.operator_instruction,last_counter=excluded.last_counter,
    grid_column=excluded.grid_column,grid_row_from_bottom=excluded.grid_row_from_bottom,
    sort_order=excluded.sort_order,active=true,note=excluded.note,updated_at=now();

  delete from public.machine_coffee_recipe_items where machine_id=v_machine_id;
  insert into public.machine_coffee_recipe_items (
    machine_id,coffee_button_id,coffee_container_id,product_id,
    container_code,ingredient_name,quantity_per_vend,unit,sort_order,active
  )
  select v_machine_id,db.id,dc.id,dc.product_id,dc.container_code,dc.product_name,
         ri.quantity_per_vend,ri.unit,ri.sort_order,true
  from public.machine_coffee_recipe_items ri
  join public.machine_coffee_buttons sb on sb.id=ri.coffee_button_id
  join public.machine_coffee_buttons db
    on db.machine_id=v_machine_id and db.selection_code=sb.selection_code and db.active
  join public.machine_coffee_containers dc
    on dc.machine_id=v_machine_id and dc.container_code=ri.container_code and dc.active
  where ri.machine_id=v_source_machine_id and ri.active;

  insert into public.machine_planogram_slots (
    machine_id,slot_code,product_name,product_sku,price_czk,dex_price_czk,
    active,sort_order,telemetry_key,customer_price_czk,settlement_type,
    settlement_amount_czk,settlement_partner,settlement_billing_enabled,
    settlement_note,planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,note
  )
  select v_machine_id,selection_code,product_name,product_sku,0,0,
         true,sort_order,selection_code,0,'none',0,null,false,null,
         null,null,null,'exact',null,null,
         'Instantní X2 slot; planogram 107 / TID 596510 / Sportisimo.'
  from public.machine_coffee_buttons where machine_id=v_machine_id and active
  on conflict (machine_id,slot_code) do update set
    product_name=excluded.product_name,product_sku=excluded.product_sku,
    price_czk=excluded.price_czk,dex_price_czk=excluded.dex_price_czk,
    active=true,sort_order=excluded.sort_order,telemetry_key=excluded.telemetry_key,
    customer_price_czk=excluded.customer_price_czk,
    settlement_type=excluded.settlement_type,
    settlement_amount_czk=excluded.settlement_amount_czk,
    settlement_partner=excluded.settlement_partner,
    settlement_billing_enabled=excluded.settlement_billing_enabled,
    settlement_note=excluded.settlement_note,
    planned_product_name=excluded.planned_product_name,
    planned_product_sku=excluded.planned_product_sku,
    planned_price_czk=excluded.planned_price_czk,
    substitution_policy=excluded.substitution_policy,
    allowed_substitutes=excluded.allowed_substitutes,
    operator_instruction=excluded.operator_instruction,note=excluded.note,updated_at=now();

  insert into public.telemetry_planogram_counters (
    provider,machine_id,planogram_slot_id,selection_code,last_total_count,last_event_at
  )
  select pr.provider,v_machine_id,s.id,b.selection_code,41,now()
  from public.machine_coffee_buttons b
  join public.machine_planogram_slots s
    on s.machine_id=v_machine_id and s.slot_code=b.selection_code
  cross join (values ('IMA'),('GP')) pr(provider)
  where b.machine_id=v_machine_id and b.active
  on conflict (provider,machine_id,planogram_slot_id,selection_code) do update
  set last_total_count=excluded.last_total_count,last_event_at=excluded.last_event_at,
      updated_at=now();
end $$;

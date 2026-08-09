-- Planogram [101] Luce X2 I-2026-07-28.xlsx
-- Machine DB id 81, evidence 101, TID 587374, Hotel Kovák location_id 59.
-- Selection 21 remains source Irish Cappuccino 300 ml / SKU 229.

do $$
declare
  v_machine_id bigint := 81;
  v_source_machine_id bigint := 73; -- verified matching instant X2 layout
begin
  update public.machines
  set location_id=59,machine_type='Coffee',brand='Rheavendors',
      name='Luce X2 I',sales_tracking_mode='telemetry',
      note=concat_ws(' ',nullif(note,''),
        'Planogram 2026-07-28; Hotel Kovák; TID 587374; instantní X2; plná telemetrie voleb 1–24.')
  where id=v_machine_id;

  insert into public.machine_external_links
    (machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','587374',true,'TID 587374 pro automat 101 / Hotel Kovák.'),
    (v_machine_id,'GP','587374',true,'TID 587374 pro automat 101 / Hotel Kovák.')
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
         'Import planogramu 101 / 2026-07-28.'
  from public.machine_coffee_containers s
  join (values
    ('Z1',1000::numeric,881::numeric),('Z2',3000::numeric,2808::numeric),
    ('Z3',3000::numeric,2703::numeric),('Z4',3000::numeric,2674::numeric),
    ('Z5',3000::numeric,2922::numeric),('Z6',3000::numeric,2978::numeric),
    ('Z7',3000::numeric,2670::numeric),('Z8',3000::numeric,2982::numeric),
    ('Z9',400::numeric,334::numeric),('Z10',350::numeric,347::numeric)
  ) d(code,capacity,current) on d.code=s.container_code
  where s.machine_id=v_source_machine_id and s.active
  union all
  select v_machine_id,'Z11',p.id,p.sku,p.name,100,99,'ks',100,'ks',100,11,true,
         'Import planogramu 101 / 2026-07-28.'
  from public.products p where p.sku='88'
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
         case when s.sort_order<=12 then 20 else 30 end,
         case when s.sort_order<=12 then 20 else 30 end,
         'none',0,null,false,null,null,null,null,'exact',null,null,
         44,s.grid_column,s.grid_row_from_bottom,s.sort_order,true,
         'Import planogramu 101 / 2026-07-28.'
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
  select v_machine_id,selection_code,product_name,product_sku,
         sale_price_czk,sale_price_czk,true,sort_order,selection_code,
         customer_price_czk,settlement_type,settlement_amount_czk,
         settlement_partner,settlement_billing_enabled,settlement_note,
         planned_product_name,planned_product_sku,planned_price_czk,
         substitution_policy,allowed_substitutes,operator_instruction,
         'Instantní X2 slot; planogram 101 / TID 587374 / Hotel Kovák.'
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
  select pr.provider,v_machine_id,s.id,b.selection_code,44,now()
  from public.machine_coffee_buttons b
  join public.machine_planogram_slots s
    on s.machine_id=v_machine_id and s.slot_code=b.selection_code
  cross join (values ('IMA'),('GP')) pr(provider)
  where b.machine_id=v_machine_id and b.active
  on conflict (provider,machine_id,planogram_slot_id,selection_code) do update
  set last_total_count=excluded.last_total_count,last_event_at=excluded.last_event_at,
      updated_at=now();
end $$;

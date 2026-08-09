-- Planogram [95] Luce X2 E-2026-07-28.xlsx
-- Machine DB id 75, evidence 95, TID 604312, GMW location_id 1.
-- User correction: selection 21 = Kakaový nápoj Cream 300 ml, SKU 235.
-- Legacy Elite SKU 5 in Z1 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 75;
  v_source_machine_id bigint := 65; -- verified matching X2 I/E recipe layout
begin
  update public.machines
  set location_id=1, machine_type='Coffee', brand='Rheavendors',
      name='Luce X2 E', sales_tracking_mode='telemetry',
      note=concat_ws(' ', nullif(note,''),
        'Planogram 2026-07-28; GMW měřící technika; TID 604312; X2 E; volby 1–24 a souhrnná telemetrie 0; Z1 Tris SKU 201; tlačítko 21 SKU 235.')
  where id=v_machine_id;

  insert into public.machine_external_links
    (machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','604312',true,'TID 604312 pro automat 95 / GMW.'),
    (v_machine_id,'GP','604312',true,'TID 604312 pro automat 95 / GMW.')
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
         case when s.container_code='Z1'
           then 'Export SKU 5 Elite; dle pravidla nahrazeno Barbera Tris SKU 201.'
           else 'Import planogramu 95 / 2026-07-28.' end
  from public.machine_coffee_containers s
  join (values
    ('Z1',3000::numeric,2990::numeric),('Z2',3000::numeric,2992::numeric),
    ('Z3',2000::numeric,1976::numeric),('Z4',2000::numeric,1966::numeric),
    ('Z5',1000::numeric, 998::numeric),('Z6',2000::numeric,1982::numeric),
    ('Z7',3000::numeric,3000::numeric),('Z8', 400::numeric, 396::numeric),
    ('Z9', 350::numeric, 350::numeric),('Z10',100::numeric,100::numeric)
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
         d.price,d.price,'none',0,null,false,null,null,null,null,
         'exact',null,null,d.counter,s.grid_column,s.grid_row_from_bottom,
         s.sort_order,true,
         case when s.selection_code='21'
           then 'Uživatelem potvrzeno: Kakaový nápoj Cream 300 ml / SKU 235.'
           else 'Import planogramu 95 / 2026-07-28.' end
  from public.machine_coffee_buttons s
  join (values
    ('1',10::numeric,1::bigint),('2',10,5),('3',10,7),('4',10,19),
    ('5',10,2),('6',10,3),('7',10,914),('8',10,43346),
    ('9',12,3401748),('10',12,2977982),('11',12,1464),('12',12,1031),
    ('13',12,1246),('14',12,1650),('15',12,2994434),('16',12,2570786),
    ('17',18,43776),('18',18,35748),('19',18,5187573),('20',18,4521412),
    ('21',18,5041),('22',18,7482),('23',18,407311),('24',18,407207)
  ) d(code,price,counter) on d.code=s.selection_code
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
         customer_price_czk,'none',0,null,false,null,null,null,null::numeric,
         'exact',null,null,'X2 E slot; planogram 95 / TID 604312.'
  from public.machine_coffee_buttons where machine_id=v_machine_id and active
  union all
  select v_machine_id,'0',p.name,p.sku,10,10,true,0,'0',10,
         'none',0,null,false,null,null,null,null::numeric,'exact',null,null,
         'Souhrnná telemetrická volba 0; planogram 95 / TID 604312.'
  from public.products p where p.sku='252'
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
  select pr.provider,v_machine_id,s.id,d.code,d.counter,now()
  from (values
    ('0',41::bigint),('1',1),('2',5),('3',7),('4',19),('5',2),('6',3),
    ('7',914),('8',43346),('9',3401748),('10',2977982),('11',1464),
    ('12',1031),('13',1246),('14',1650),('15',2994434),('16',2570786),
    ('17',43776),('18',35748),('19',5187573),('20',4521412),('21',5041),
    ('22',7482),('23',407311),('24',407207)
  ) d(code,counter)
  join public.machine_planogram_slots s
    on s.machine_id=v_machine_id and s.slot_code=d.code
  cross join (values ('IMA'),('GP')) pr(provider)
  on conflict (provider,machine_id,planogram_slot_id,selection_code) do update
  set last_total_count=excluded.last_total_count,last_event_at=excluded.last_event_at,
      updated_at=now();
end $$;

-- Planogram [28] Luce X2 I_E-2026-07-28.xlsx
-- Machine DB id 23, evidence 28, TID 602228.
-- Location: BVK Pisárky, hlavní budova (location_id 6).
-- Full X2 telemetry: selections 1-24, no aggregate selection 0.
-- Elite / code 5 is mapped to Barbera Tris SKU 201.

do $$
declare
  v_machine_id bigint := 23;
begin
  update public.machines
  set location_id=6, machine_type='Coffee', brand='Rheavendors',
      name='Luce X2 I/E', sales_tracking_mode='telemetry',
      note=concat_ws(' ',nullif(note,''),
        'Planogram 2026-07-28; BVK Pisárky hl. budova; TID 602228; plná telemetrie voleb 1–24.')
  where id=v_machine_id;

  insert into public.machine_external_links(machine_id,provider,external_machine_id,telemetry_enabled,note)
  values
    (v_machine_id,'IMA','602228',true,'TID 602228 pro Luce X2 I/E / automat 28 / BVK Pisárky hl. budova.'),
    (v_machine_id,'GP','602228',true,'TID 602228 pro Luce X2 I/E / automat 28 / BVK Pisárky hl. budova.')
  on conflict(provider,external_machine_id) do update
  set machine_id=excluded.machine_id,telemetry_enabled=true,note=excluded.note,updated_at=now();

  update public.machine_coffee_containers set active=false where machine_id=v_machine_id;
  update public.machine_coffee_buttons set active=false where machine_id=v_machine_id;
  update public.machine_planogram_slots set active=false where machine_id=v_machine_id;

  insert into public.machine_coffee_containers(
    machine_id,container_code,product_id,product_sku,product_name,
    capacity_quantity,current_quantity,unit,refill_package_quantity,
    refill_package_unit,min_refill_quantity,sort_order,active,note
  )
  select v_machine_id,d.code,p.id,p.sku,p.name,d.capacity,d.current,d.unit,
         d.package,d.package_unit,d.package,d.sort_order,true,
         'Import planogramu 28 / 2026-07-28.'
           || case when d.code='Z1' then ' Excel Elite / kód 5 je mapovaný na Barbera Tris / SKU 201.'
                   when d.code='Z8' then ' Export uvádí kelímek po 100 ks, skladově doplňujeme po 50 ks.'
                   else '' end
  from(values
    ('Z1','201',3000::numeric,2980::numeric,'g',1000::numeric,'g',1),
    ('Z2','43', 3000::numeric,2962::numeric,'g',1500::numeric,'g',2),
    ('Z3','48', 2000::numeric,1920::numeric,'g',1000::numeric,'g',3),
    ('Z4','47', 2000::numeric,1944::numeric,'g',1000::numeric,'g',4),
    ('Z5','44', 1000::numeric, 983::numeric,'g', 500::numeric,'g',5),
    ('Z6','46', 2000::numeric,1978::numeric,'g',1000::numeric,'g',6),
    ('Z7','49', 3000::numeric,2982::numeric,'g',1000::numeric,'g',7),
    ('Z8','45',  400::numeric, 392::numeric,'ks',50::numeric,'ks',8),
    ('Z9','53',  350::numeric, 348::numeric,'ks',50::numeric,'ks',9),
    ('Z10','88', 100::numeric, 100::numeric,'ks',100::numeric,'ks',10)
  )d(code,sku,capacity,current,unit,package,package_unit,sort_order)
  join public.products p on p.sku=d.sku
  on conflict(machine_id,container_code) do update
  set product_id=excluded.product_id,product_sku=excluded.product_sku,
      product_name=excluded.product_name,capacity_quantity=excluded.capacity_quantity,
      current_quantity=excluded.current_quantity,unit=excluded.unit,
      refill_package_quantity=excluded.refill_package_quantity,
      refill_package_unit=excluded.refill_package_unit,
      min_refill_quantity=excluded.min_refill_quantity,sort_order=excluded.sort_order,
      active=true,note=excluded.note,updated_at=now();

  insert into public.machine_coffee_buttons(
    machine_id,selection_code,product_id,product_sku,product_name,
    sale_price_czk,customer_price_czk,settlement_type,settlement_amount_czk,
    settlement_partner,settlement_billing_enabled,settlement_note,
    planned_product_name,planned_product_sku,planned_price_czk,
    substitution_policy,allowed_substitutes,operator_instruction,
    last_counter,grid_column,grid_row_from_bottom,sort_order,active,note
  )
  select v_machine_id,d.code,p.id,p.sku,p.name,d.price,d.price,'none',0,
         null,false,null,null,null,null,'exact',null,
         case when d.code='7' then
           'Potvrzená místní odchylka: složku white-choc z katalogové receptury mapovat na Z7 / Lemon SKU 49.'
         else null end,
         d.counter,d.col,d.row_bottom,d.sort_order,true,
         'Import planogramu 28 / 2026-07-28.'
           || case when d.code='7' then ' Potvrzeno: white-choc složka katalogové receptury je pro tento automat nahrazena Lemon SKU 49 ze Z7.' else '' end
  from(values
    ('1','239',14::numeric,468::integer,1,4,1),
    ('2','215',14::numeric,1322::integer,1,3,2),
    ('3','222',14::numeric,805::integer,1,2,3),
    ('4','230',14::numeric,3655::integer,1,1,4),
    ('5','233',14::numeric,817::integer,2,4,5),
    ('6','234',14::numeric,1655::integer,2,3,6),
    ('7','236',14::numeric,1994::integer,2,2,7),
    ('8','250',14::numeric,1255::integer,2,1,8),
    ('9','224',16::numeric,1820::integer,3,4,9),
    ('10','225',16::numeric,1028::integer,3,3,10),
    ('11','221',16::numeric,2084::integer,3,2,11),
    ('12','241',16::numeric,2382::integer,3,1,12),
    ('13','226',16::numeric,341::integer,4,4,13),
    ('14','227',16::numeric,435::integer,4,3,14),
    ('15','244',16::numeric,771::integer,4,2,15),
    ('16','228',16::numeric,373::integer,4,1,16),
    ('17','240',20::numeric,351::integer,5,4,17),
    ('18','216',20::numeric,606::integer,5,3,18),
    ('19','223',20::numeric,1093::integer,5,2,19),
    ('20','229',20::numeric,4534::integer,5,1,20),
    ('21','232',20::numeric,2572::integer,6,4,21),
    ('22','251',20::numeric,1777::integer,6,3,22),
    ('23','246',20::numeric,187::integer,6,2,23),
    ('24','243',20::numeric,2566::integer,6,1,24)
  )d(code,sku,price,counter,col,row_bottom,sort_order)
  join public.products p on p.sku=d.sku
  on conflict(machine_id,selection_code) do update
  set product_id=excluded.product_id,product_sku=excluded.product_sku,
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
      operator_instruction=excluded.operator_instruction,
      last_counter=excluded.last_counter,grid_column=excluded.grid_column,
      grid_row_from_bottom=excluded.grid_row_from_bottom,sort_order=excluded.sort_order,
      active=true,note=excluded.note,updated_at=now();

  delete from public.machine_coffee_recipe_items where machine_id=v_machine_id;
  insert into public.machine_coffee_recipe_items(
    machine_id,coffee_button_id,coffee_container_id,product_id,
    container_code,ingredient_name,quantity_per_vend,unit,sort_order,active
  )
  select v_machine_id,b.id,c.id,ri.product_id,c.container_code,c.product_name,
         ri.quantity,ri.unit,ri.id,true
  from public.machine_coffee_buttons b
  join lateral(
    select r.* from public.recipes r
    where r.machine_type='product_catalog'
      and r.selection_code='product:'||b.product_id::text
    order by(r.sale_price=b.sale_price_czk)desc nulls last,r.id desc limit 1
  )r on true
  join public.recipe_items ri on ri.recipe_id=r.id
  left join public.machine_coffee_containers c
    on c.machine_id=v_machine_id and c.product_id=ri.product_id
  where b.machine_id=v_machine_id and b.active;

  update public.machine_coffee_recipe_items i
  set coffee_container_id=c.id,product_id=c.product_id,
      container_code=c.container_code,ingredient_name=c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id=b.machine_id and c.container_code='Z8'
  where i.machine_id=v_machine_id and i.coffee_button_id=b.id
    and b.machine_id=v_machine_id
    and b.selection_code in('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16')
    and i.product_id in(
      select id from public.products
      where sku in('45','79','255')
         or lower(name)like'kelímek 180 ml%'
         or lower(name)like'kelímek 250 ml%'
    );

  update public.machine_coffee_recipe_items i
  set coffee_container_id=c.id,product_id=c.product_id,
      container_code=c.container_code,ingredient_name=c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id=b.machine_id and c.container_code='Z9'
  where i.machine_id=v_machine_id and i.coffee_button_id=b.id
    and b.machine_id=v_machine_id
    and b.selection_code in('17','18','19','20','21','22','23','24')
    and i.product_id in(
      select id from public.products
      where sku in('53','79') or lower(name)like'kelímek 300 ml%'
    );

  -- Potvrzená lokální receptura: volba 7 používá místo white-choc fyzický Z7 / Lemon SKU 49.
  update public.machine_coffee_recipe_items i
  set coffee_container_id=c.id,
      product_id=c.product_id,
      container_code=c.container_code,
      ingredient_name=c.product_name
  from public.machine_coffee_buttons b
  join public.machine_coffee_containers c
    on c.machine_id=b.machine_id and c.container_code='Z7'
  where i.machine_id=v_machine_id
    and i.coffee_button_id=b.id
    and b.machine_id=v_machine_id
    and b.selection_code='7'
    and i.product_id in(
      select id from public.products where sku='51'
    );

  insert into public.machine_planogram_slots(
    machine_id,slot_code,product_name,product_sku,price_czk,dex_price_czk,
    capacity_units,current_units,fill_percent,active,sort_order,telemetry_key,
    customer_price_czk,settlement_type,settlement_amount_czk,settlement_partner,
    settlement_billing_enabled,settlement_note,planned_product_name,
    planned_product_sku,planned_price_czk,substitution_policy,
    allowed_substitutes,operator_instruction,note
  )
  select v_machine_id,selection_code,product_name,product_sku,sale_price_czk,
         sale_price_czk,null,null,null,active,sort_order,selection_code,
         customer_price_czk,settlement_type,settlement_amount_czk,settlement_partner,
         settlement_billing_enabled,settlement_note,planned_product_name,
         planned_product_sku,planned_price_czk,substitution_policy,
         allowed_substitutes,operator_instruction,
         'Zrcadlový slot plné X2 telemetrie TID 602228 / BVK Pisárky hl. budova.'
  from public.machine_coffee_buttons where machine_id=v_machine_id
  on conflict(machine_id,slot_code) do update
  set product_name=excluded.product_name,product_sku=excluded.product_sku,
      price_czk=excluded.price_czk,dex_price_czk=excluded.dex_price_czk,
      active=excluded.active,sort_order=excluded.sort_order,
      telemetry_key=excluded.telemetry_key,
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
      operator_instruction=excluded.operator_instruction,
      note=excluded.note,updated_at=now();

  insert into public.telemetry_planogram_counters(
    provider,machine_id,planogram_slot_id,selection_code,last_total_count,last_event_at
  )
  select provider.provider,v_machine_id,slot.id,counter.code,counter.total,now()
  from(values
    ('1',468),('2',1322),('3',805),('4',3655),('5',817),('6',1655),
    ('7',1994),('8',1255),('9',1820),('10',1028),('11',2084),('12',2382),
    ('13',341),('14',435),('15',771),('16',373),('17',351),('18',606),
    ('19',1093),('20',4534),('21',2572),('22',1777),('23',187),('24',2566)
  )counter(code,total)
  join public.machine_planogram_slots slot
    on slot.machine_id=v_machine_id and slot.slot_code=counter.code
  cross join(values('IMA'),('GP'))provider(provider)
  on conflict(provider,machine_id,planogram_slot_id,selection_code)do update
  set last_total_count=excluded.last_total_count,last_event_at=excluded.last_event_at,updated_at=now();
end $$;

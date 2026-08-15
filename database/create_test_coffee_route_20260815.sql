begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_vehicle bigint := 1;
  v_location bigint;
  v_machine bigint;
  v_route bigint;
  v_vehicle_stock bigint;
  v_coffee bigint;
  v_milk bigint;
  v_cocoa bigint;
  v_cups bigint;
  v_z1 bigint;
  v_z2 bigint;
  v_z3 bigint;
  v_z4 bigint;
  v_b1 bigint;
  v_b2 bigint;
  v_b3 bigint;
begin
  select id into v_location from public.locations where name='[TEST] Mobilní práce u Luce X2' limit 1;
  if v_location is null then
    insert into public.locations(name,city,address,customer_name,active,route_note,latitude,longitude)
    values ('[TEST] Mobilní práce u Luce X2','Olomouc','Testovací lokalita – nevyrážet fyzicky','OLVEND TEST',true,'Pouze pro vyzkoušení nového mobilního postupu.',49.5938,17.2509)
    returning id into v_location;
  end if;

  select id into v_machine from public.machines where note like '%TEST_COFFEE_GUIDED_V41%' limit 1;
  if v_machine is null then
    insert into public.machines(location_id,name,machine_type,brand,model,serial_number,status,active,note,qr_token,evidence_number,sales_tracking_mode)
    values (v_location,'Luce X2 I/E · TEST','coffee','Rheavendors','Luce X2','TEST-LUCE-X2-0001','ok',true,'TEST_COFFEE_GUIDED_V41 · zkušební automat pro Michala','test-luce-x2-v41',9991,'telemetry')
    returning id into v_machine;
  else
    update public.machines set location_id=v_location,active=true,status='ok',sales_tracking_mode='telemetry' where id=v_machine;
  end if;

  insert into public.machine_external_links(machine_id,provider,external_machine_id,telemetry_enabled,note)
  values(v_machine,'test','TEST-LUCE-X2-9991',true,'Testovací telemetrie pro nový mobilní průchod')
  on conflict(provider,external_machine_id) do update set machine_id=excluded.machine_id,telemetry_enabled=true;

  insert into public.products(name,sku,product_category,usage_type,base_unit,vat_rate,active,note,can_be_used_in_recipe)
  values('[TEST] Káva Brazil 1 kg','TEST-COFFEE-V41','ingredient','recipe_consumption','kg',12,true,'Pouze zkušební mobilní trasa',true)
  on conflict(sku) do update set active=true
  returning id into v_coffee;
  insert into public.products(name,sku,product_category,usage_type,base_unit,vat_rate,active,note,can_be_used_in_recipe)
  values('[TEST] Sušené mléko 1 kg','TEST-MILK-V41','ingredient','recipe_consumption','kg',12,true,'Pouze zkušební mobilní trasa',true)
  on conflict(sku) do update set active=true
  returning id into v_milk;
  insert into public.products(name,sku,product_category,usage_type,base_unit,vat_rate,active,note,can_be_used_in_recipe)
  values('[TEST] Čokoláda 1 kg','TEST-COCOA-V41','ingredient','recipe_consumption','kg',12,true,'Pouze zkušební mobilní trasa',true)
  on conflict(sku) do update set active=true
  returning id into v_cocoa;
  insert into public.products(name,sku,product_category,usage_type,base_unit,vat_rate,active,note,can_be_used_in_recipe)
  values('[TEST] Kelímek 180 ml','TEST-CUPS-V41','consumable','recipe_consumption','ks',21,true,'Pouze zkušební mobilní trasa',true)
  on conflict(sku) do update set active=true
  returning id into v_cups;

  insert into public.product_packages(product_id,package_name,units_per_package,is_default,active)
  select v_coffee,'balení 1 kg',1,true,true where not exists(select 1 from public.product_packages where product_id=v_coffee and is_default);
  insert into public.product_packages(product_id,package_name,units_per_package,is_default,active)
  select v_milk,'balení 1 kg',1,true,true where not exists(select 1 from public.product_packages where product_id=v_milk and is_default);
  insert into public.product_packages(product_id,package_name,units_per_package,is_default,active)
  select v_cocoa,'balení 1 kg',1,true,true where not exists(select 1 from public.product_packages where product_id=v_cocoa and is_default);
  insert into public.product_packages(product_id,package_name,units_per_package,is_default,active)
  select v_cups,'balení 50 ks',50,true,true where not exists(select 1 from public.product_packages where product_id=v_cups and is_default);

  select id into v_z1 from public.machine_coffee_containers where machine_id=v_machine and container_code='Z1';
  if v_z1 is null then
    insert into public.machine_coffee_containers(machine_id,container_code,product_id,product_sku,product_name,capacity_quantity,current_quantity,unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active)
    values(v_machine,'Z1',v_coffee,'TEST-COFFEE-V41','[TEST] Káva Brazil 1 kg',3000,1000,'g',1000,'g',1000,10,true) returning id into v_z1;
    insert into public.machine_coffee_containers(machine_id,container_code,product_id,product_sku,product_name,capacity_quantity,current_quantity,unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active)
    values(v_machine,'Z2',v_milk,'TEST-MILK-V41','[TEST] Sušené mléko 1 kg',2000,500,'g',1000,'g',1000,20,true) returning id into v_z2;
    insert into public.machine_coffee_containers(machine_id,container_code,product_id,product_sku,product_name,capacity_quantity,current_quantity,unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active)
    values(v_machine,'Z3',v_cocoa,'TEST-COCOA-V41','[TEST] Čokoláda 1 kg',2000,1000,'g',1000,'g',1000,30,true) returning id into v_z3;
    insert into public.machine_coffee_containers(machine_id,container_code,product_id,product_sku,product_name,capacity_quantity,current_quantity,unit,refill_package_quantity,refill_package_unit,min_refill_quantity,sort_order,active)
    values(v_machine,'Z4',v_cups,'TEST-CUPS-V41','[TEST] Kelímek 180 ml',300,200,'ks',50,'ks',50,40,true) returning id into v_z4;
  else
    select id into v_z2 from public.machine_coffee_containers where machine_id=v_machine and container_code='Z2';
    select id into v_z3 from public.machine_coffee_containers where machine_id=v_machine and container_code='Z3';
    select id into v_z4 from public.machine_coffee_containers where machine_id=v_machine and container_code='Z4';
    update public.machine_coffee_containers set current_quantity=case container_code when 'Z1' then 1000 when 'Z2' then 500 when 'Z3' then 1000 else 200 end,active=true where machine_id=v_machine;
  end if;

  select id into v_b1 from public.machine_coffee_buttons where machine_id=v_machine and selection_code='1';
  if v_b1 is null then
    insert into public.machine_coffee_buttons(machine_id,selection_code,product_id,product_sku,product_name,sale_price_czk,customer_price_czk,sort_order,active)
    values(v_machine,'1',v_coffee,'TEST-ESPRESSO-V41','Espresso',15,15,10,true) returning id into v_b1;
    insert into public.machine_coffee_buttons(machine_id,selection_code,product_id,product_sku,product_name,sale_price_czk,customer_price_czk,sort_order,active)
    values(v_machine,'7',v_coffee,'TEST-CAPPUCCINO-V41','Cappuccino bez cukru',20,20,20,true) returning id into v_b2;
    insert into public.machine_coffee_buttons(machine_id,selection_code,product_id,product_sku,product_name,sale_price_czk,customer_price_czk,sort_order,active)
    values(v_machine,'12',v_cocoa,'TEST-CHOCOLATE-V41','Horká čokoláda',20,20,30,true) returning id into v_b3;
  else
    select id into v_b2 from public.machine_coffee_buttons where machine_id=v_machine and selection_code='7';
    select id into v_b3 from public.machine_coffee_buttons where machine_id=v_machine and selection_code='12';
  end if;

  if not exists(select 1 from public.machine_coffee_recipe_items where machine_id=v_machine) then
    insert into public.machine_coffee_recipe_items(machine_id,coffee_button_id,coffee_container_id,container_code,ingredient_name,quantity_per_vend,unit,sort_order,active,product_id)
    values
      (v_machine,v_b1,v_z1,'Z1','Káva',8,'g',10,true,v_coffee),
      (v_machine,v_b1,v_z4,'Z4','Kelímek',1,'ks',20,true,v_cups),
      (v_machine,v_b2,v_z1,'Z1','Káva',8,'g',10,true,v_coffee),
      (v_machine,v_b2,v_z2,'Z2','Mléko',14,'g',20,true,v_milk),
      (v_machine,v_b2,v_z4,'Z4','Kelímek',1,'ks',30,true,v_cups),
      (v_machine,v_b3,v_z3,'Z3','Čokoláda',22,'g',10,true,v_cocoa),
      (v_machine,v_b3,v_z4,'Z4','Kelímek',1,'ks',20,true,v_cups);
  end if;

  select id into v_vehicle_stock from public.stock_locations where location_type='vehicle' and vehicle_id=v_vehicle and active is true limit 1;
  if v_vehicle_stock is null then
    insert into public.stock_locations(location_type,name,vehicle_id,active,note)
    values('vehicle','Renault Kangoo · 2TX7928',v_vehicle,true,'Sklad vozidla') returning id into v_vehicle_stock;
  end if;
  insert into public.stock_location_balances(stock_location_id,product_id,batch_id,quantity_on_hand,reserved_quantity)
  select v_vehicle_stock,p.id,null,case when p.id=v_cups then 500 else 10 end,0
  from (values(v_coffee),(v_milk),(v_cocoa),(v_cups)) p(id)
  where not exists(select 1 from public.stock_location_balances b where b.stock_location_id=v_vehicle_stock and b.product_id=p.id and b.batch_id is null);
  update public.stock_location_balances set quantity_on_hand=case when product_id=v_cups then greatest(quantity_on_hand,500) else greatest(quantity_on_hand,10) end
  where stock_location_id=v_vehicle_stock and product_id in(v_coffee,v_milk,v_cocoa,v_cups) and batch_id is null;

  if not exists(select 1 from public.telemetry_sales_events where machine_id=v_machine and source_event_key='TEST-V41-CASH-260') then
    insert into public.telemetry_sales_events(provider,machine_id,selection_code,product_name,quantity,cash_quantity,cashless_quantity,unit_price_czk,total_amount_czk,cash_amount_czk,cashless_amount_czk,source_event_at,source_event_key,source_location_name,source_machine_name)
    values('test',v_machine,'7','Cappuccino bez cukru',13,13,0,20,260,260,0,now()-interval '2 hours','TEST-V41-CASH-260','[TEST] Mobilní práce u Luce X2','TEST Luce X2');
  end if;

  select id into v_route from public.route_plans where title='[TEST] Nový mobilní postup · Luce X2' and planning_date=current_date limit 1;
  if v_route is null then
    insert into public.route_plans(planning_date,title,vehicle_id,planned_employee_id,warehouse_id,planner_mode,optimization_provider,provider_status,return_to_start,stop_count,estimated_distance_km,estimated_drive_minutes,estimated_service_minutes,execution_status,assigned_at,planned_departure_time,route_payload)
    values(current_date,'[TEST] Nový mobilní postup · Luce X2',v_vehicle,v_employee,1,'warehouse','heuristic','ready',false,1,0,0,25,'assigned',now(),localtime,jsonb_build_object('test_mode',true,'coffee_guided_version',41,'instructions','Zkušební trasa – nevyrážet fyzicky.'))
    returning id into v_route;
  else
    update public.route_plans set vehicle_id=v_vehicle,planned_employee_id=v_employee,execution_status='assigned',assigned_at=now(),started_at=null,completed_at=null,return_to_start=false,route_payload=jsonb_build_object('test_mode',true,'coffee_guided_version',41,'instructions','Zkušební trasa – nevyrážet fyzicky.') where id=v_route;
    delete from public.route_machine_visits where route_plan_id=v_route;
    delete from public.route_plan_stops where route_plan_id=v_route;
  end if;
  insert into public.route_plan_stops(route_plan_id,location_id,machine_id,stop_order,stop_kind,status,title,address_snapshot,city_snapshot,latitude,longitude,estimated_service_minutes,note)
  values(v_route,v_location,v_machine,1,'restock','planned','[TEST] Rheavendors Luce X2','Testovací lokalita – nikam nejezdit','Olomouc',49.5938,17.2509,25,'Vyzkoušej celý nový postup v telefonu. Jde pouze o testovací data.');
end;
$$;

commit;

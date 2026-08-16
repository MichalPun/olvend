-- Izolovaná kopie Rigumu pro realistický test nového potravinového průchodu.
-- Používá skutečný účet, vozidlo, produkty a šarže vozidla, nikdy živý automat EV 100.

begin;

do $$
declare
  v_employee constant uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_vehicle constant bigint := 1;
  v_vehicle_stock bigint;
  v_source_location bigint;
  v_target_location bigint;
  v_source_machine bigint;
  v_target_machine bigint;
  v_source_stock bigint;
  v_target_stock bigint;
  v_route bigint;
  v_short_batch bigint;
  v_expired_batch bigint;
  v_target_batch bigint;
  v_product_bagette bigint;
  v_product_dr_witt bigint;
  v_product_dr_witt_sub bigint;
  v_product_pepsi bigint;
  v_product_nestea bigint;
  v_pepsi_batch bigint;
  v_nestea_batch bigint;
begin
  if not exists(select 1 from public.employees where id=v_employee and active is true) then
    raise exception 'Testovací účet Michala není aktivní.';
  end if;
  if not exists(select 1 from public.vehicles where id=v_vehicle) then
    raise exception 'Vozidlo #1 nebylo nalezeno.';
  end if;

  select id into v_vehicle_stock
  from public.stock_locations
  where location_type='vehicle' and vehicle_id=v_vehicle and active is true
  order by id
  limit 1;
  if v_vehicle_stock is null then
    raise exception 'Aktivní sklad vozidla #1 nebyl nalezen.';
  end if;

  select id into v_product_bagette from public.products where sku='155' and active is true;
  select id into v_product_dr_witt from public.products where sku='276' and active is true;
  select id into v_product_dr_witt_sub from public.products where sku='200' and active is true;
  select id into v_product_pepsi from public.products where sku='71' and active is true;
  select id into v_product_nestea from public.products where sku='275' and active is true;
  if v_product_bagette is null or v_product_dr_witt is null or v_product_dr_witt_sub is null
     or v_product_pepsi is null or v_product_nestea is null then
    raise exception 'Některý z ověřených produktů Rigumu chybí.';
  end if;

  if not exists(
    select 1 from public.stock_location_balances
    where stock_location_id=v_vehicle_stock and product_id=v_product_bagette and quantity_on_hand >= 7
  ) then
    raise exception 'Ve vozidle není alespoň 7 ks ATM Debrecínské bagety pro realistický test.';
  end if;
  if not exists(
    select 1 from public.stock_location_balances
    where stock_location_id=v_vehicle_stock and product_id=v_product_dr_witt_sub and quantity_on_hand >= 1
  ) then
    raise exception 'Ve vozidle není schválená záměna DrWitt liči+hruška.';
  end if;

  select id into v_source_location from public.locations where name='[TEST] RIGUM · nový potravinový průchod' limit 1;
  if v_source_location is null then
    insert into public.locations(name,city,address,customer_name,active,route_note,latitude,longitude)
    values('[TEST] RIGUM · nový potravinový průchod','Dubňany','Jarohněvice 1666 · TEST, nikam nejezdit','OLVEND TEST',true,'Izolovaná kopie Rigumu pro test mobilní aplikace.',48.9236612,17.0718631)
    returning id into v_source_location;
  else
    update public.locations
    set active=true,city='Dubňany',address='Jarohněvice 1666 · TEST, nikam nejezdit',latitude=48.9236612,longitude=17.0718631
    where id=v_source_location;
  end if;

  select id into v_target_location from public.locations where name='[TEST] RIGUM · místo pro doprodání' limit 1;
  if v_target_location is null then
    insert into public.locations(name,city,address,customer_name,active,route_note,latitude,longitude)
    values('[TEST] RIGUM · místo pro doprodání','Dubňany','Testovací druhá zastávka · nikam nejezdit','OLVEND TEST',true,'Cíl doporučeného přesunu krátké expirace.',48.9351000,17.1025000)
    returning id into v_target_location;
  else
    update public.locations
    set active=true,city='Dubňany',address='Testovací druhá zastávka · nikam nejezdit',latitude=48.9351000,longitude=17.1025000
    where id=v_target_location;
  end if;

  select id into v_source_machine from public.machines where qr_token='test-rigum-food-v42-source' limit 1;
  if v_source_machine is null then
    insert into public.machines(location_id,name,machine_type,brand,model,serial_number,status,active,note,qr_token,evidence_number,sales_tracking_mode)
    values(v_source_location,'ARIA L EVO · TEST RIGUM','Snack','Rheavendors','ARIA L EVO','TEST-RIGUM-V42-A','ok',true,'TEST_FOOD_GUIDED_V42_SOURCE','test-rigum-food-v42-source',9901,'telemetry')
    returning id into v_source_machine;
  else
    update public.machines set location_id=v_source_location,active=true,status='ok',sales_tracking_mode='telemetry' where id=v_source_machine;
  end if;

  select id into v_target_machine from public.machines where qr_token='test-rigum-food-v42-target' limit 1;
  if v_target_machine is null then
    insert into public.machines(location_id,name,machine_type,brand,model,serial_number,status,active,note,qr_token,evidence_number,sales_tracking_mode)
    values(v_target_location,'ARIA L EVO · TEST DOPRODÁNÍ','Snack','Rheavendors','ARIA L EVO','TEST-RIGUM-V42-B','ok',true,'TEST_FOOD_GUIDED_V42_TARGET','test-rigum-food-v42-target',9902,'telemetry')
    returning id into v_target_machine;
  else
    update public.machines set location_id=v_target_location,active=true,status='ok',sales_tracking_mode='telemetry' where id=v_target_machine;
  end if;

  insert into public.machine_planogram_slots(
    machine_id,slot_code,product_name,product_sku,price_czk,current_units,capacity_units,desired_units,target_units,
    expiry_date,telemetry_key,sort_order,active,product_family,product_variant,substitution_policy,allowed_substitutes,operator_instruction,note
  ) values
    (v_source_machine,'41','ATM Debrecínská bageta','155',55,3,6,3,6,current_date+1,'41',10,true,'ATM bageta','Debrecínská','exact',null,'Fyzicky ověř počet a expiraci. Aplikace může doporučit přesun.','TEST FOOD V42 · krátká expirace'),
    (v_source_machine,'42','ATM Debrecínská bageta','155',55,2,6,4,6,current_date-1,'42',20,true,'ATM bageta','Debrecínská','exact',null,'Prošlé kusy musí být odepsané.','TEST FOOD V42 · prošlá expirace'),
    (v_source_machine,'46','DrWitt Isotonic Vitamin Minerální voda citrus 550ml PET','276',29,0,6,6,6,null,'46',30,true,'DrWitt 550 ml','citrus','approved_list','DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200','Hlavní druh není ve vozidle; vyzkoušej schválenou záměnu SKU 200.','TEST FOOD V42 · záměna'),
    (v_source_machine,'51','Pepsi Cola 500ml PET','71',35,5,6,1,6,current_date+90,'51',40,true,'Pepsi 500 ml','cola','exact',null,null,'TEST FOOD V42'),
    (v_source_machine,'52','Nestea Lemon 0,5l','275',35,3,6,3,6,current_date+120,'52',50,true,'Nestea 500 ml','lemon','approved_list','Nestea Lemon 0,5l (SKU 275)',null,'TEST FOOD V42')
  on conflict(machine_id,slot_code) do update set
    product_name=excluded.product_name,product_sku=excluded.product_sku,price_czk=excluded.price_czk,
    current_units=excluded.current_units,capacity_units=excluded.capacity_units,desired_units=excluded.desired_units,target_units=excluded.target_units,
    expiry_date=excluded.expiry_date,telemetry_key=excluded.telemetry_key,sort_order=excluded.sort_order,active=true,
    product_family=excluded.product_family,product_variant=excluded.product_variant,substitution_policy=excluded.substitution_policy,
    allowed_substitutes=excluded.allowed_substitutes,operator_instruction=excluded.operator_instruction,note=excluded.note;

  insert into public.machine_planogram_slots(
    machine_id,slot_code,product_name,product_sku,price_czk,current_units,capacity_units,desired_units,target_units,
    expiry_date,telemetry_key,sort_order,active,product_family,product_variant,substitution_policy,operator_instruction,note
  ) values
    (v_target_machine,'41','ATM Debrecínská bageta','155',55,1,6,5,6,current_date+3,'41',10,true,'ATM bageta','Debrecínská','exact','Tady se má nabídnout doprodání krátké expirace.','TEST FOOD V42 · cíl přesunu'),
    (v_target_machine,'46','DrWitt Isotonic Vitamin Minerální voda citrus 550ml PET','276',29,6,6,0,6,current_date+90,'46',20,true,'DrWitt 550 ml','citrus','approved_list',null,'TEST FOOD V42')
  on conflict(machine_id,slot_code) do update set
    product_name=excluded.product_name,product_sku=excluded.product_sku,price_czk=excluded.price_czk,
    current_units=excluded.current_units,capacity_units=excluded.capacity_units,desired_units=excluded.desired_units,target_units=excluded.target_units,
    expiry_date=excluded.expiry_date,telemetry_key=excluded.telemetry_key,sort_order=excluded.sort_order,active=true,
    product_family=excluded.product_family,product_variant=excluded.product_variant,substitution_policy=excluded.substitution_policy,
    operator_instruction=excluded.operator_instruction,note=excluded.note;

  select id into v_source_stock from public.stock_locations where location_type='machine' and machine_id=v_source_machine and active is true limit 1;
  if v_source_stock is null then
    insert into public.stock_locations(location_type,name,machine_id,active,note)
    values('machine','[TEST] RIGUM · zásoba automatu',v_source_machine,true,'TEST FOOD V42') returning id into v_source_stock;
  end if;
  select id into v_target_stock from public.stock_locations where location_type='machine' and machine_id=v_target_machine and active is true limit 1;
  if v_target_stock is null then
    insert into public.stock_locations(location_type,name,machine_id,active,note)
    values('machine','[TEST] DOPRODÁNÍ · zásoba automatu',v_target_machine,true,'TEST FOOD V42') returning id into v_target_stock;
  end if;

  select id into v_short_batch from public.inventory_batches where product_id=v_product_bagette and lot_code='TEST-RIGUM-V42-SHORT' limit 1;
  if v_short_batch is null then
    insert into public.inventory_batches(product_id,lot_code,use_by_date,received_at,note)
    values(v_product_bagette,'TEST-RIGUM-V42-SHORT',current_date+1,now(),'Pouze izolovaný test FOOD V42') returning id into v_short_batch;
  else
    update public.inventory_batches set use_by_date=current_date+1 where id=v_short_batch;
  end if;
  select id into v_expired_batch from public.inventory_batches where product_id=v_product_bagette and lot_code='TEST-RIGUM-V42-EXPIRED' limit 1;
  if v_expired_batch is null then
    insert into public.inventory_batches(product_id,lot_code,use_by_date,received_at,note)
    values(v_product_bagette,'TEST-RIGUM-V42-EXPIRED',current_date-1,now(),'Pouze izolovaný test FOOD V42') returning id into v_expired_batch;
  else
    update public.inventory_batches set use_by_date=current_date-1 where id=v_expired_batch;
  end if;
  select id into v_target_batch from public.inventory_batches where product_id=v_product_bagette and lot_code='TEST-RIGUM-V42-TARGET' limit 1;
  if v_target_batch is null then
    insert into public.inventory_batches(product_id,lot_code,use_by_date,received_at,note)
    values(v_product_bagette,'TEST-RIGUM-V42-TARGET',current_date+3,now(),'Pouze izolovaný test FOOD V42') returning id into v_target_batch;
  else
    update public.inventory_batches set use_by_date=current_date+3 where id=v_target_batch;
  end if;

  select batch_id into v_pepsi_batch from public.stock_location_balances
  where stock_location_id=v_vehicle_stock and product_id=v_product_pepsi and quantity_on_hand>0 and batch_id is not null
  order by quantity_on_hand desc limit 1;
  select batch_id into v_nestea_batch from public.stock_location_balances
  where stock_location_id=v_vehicle_stock and product_id=v_product_nestea and quantity_on_hand>0 and batch_id is not null
  order by quantity_on_hand desc limit 1;
  if v_pepsi_batch is null or v_nestea_batch is null then
    raise exception 'Ve vozidle chybí šarže Pepsi nebo Nestea pro test FEFO.';
  end if;

  delete from public.stock_location_balances where stock_location_id in(v_source_stock,v_target_stock);
  insert into public.stock_location_balances(stock_location_id,product_id,batch_id,quantity_on_hand,reserved_quantity)
  values
    (v_source_stock,v_product_bagette,v_short_batch,3,0),
    (v_source_stock,v_product_bagette,v_expired_batch,2,0),
    (v_source_stock,v_product_pepsi,v_pepsi_batch,5,0),
    (v_source_stock,v_product_nestea,v_nestea_batch,3,0),
    (v_target_stock,v_product_bagette,v_target_batch,1,0);

  delete from public.telemetry_sales_events where provider='test-food-v42' and machine_id in(v_source_machine,v_target_machine);
  insert into public.telemetry_sales_events(
    provider,machine_id,selection_code,product_name,product_sku,quantity,cash_quantity,cashless_quantity,
    unit_price_czk,total_amount_czk,cash_amount_czk,cashless_amount_czk,source_event_at,source_event_key,source_location_name,source_machine_name
  ) values
    ('test-food-v42',v_source_machine,'CASH','Testovací hotovost',null,13,13,0,20,260,260,0,now()-interval '2 hours','TEST-FOOD-V42-CASH','[TEST] RIGUM','TEST RIGUM SOURCE'),
    ('test-food-v42',v_target_machine,'41','ATM Debrecínská bageta','155',14,0,14,55,770,0,770,now()-interval '1 day','TEST-FOOD-V42-SALES','[TEST] DOPRODÁNÍ','TEST RIGUM TARGET');

  select id into v_route
  from public.route_plans
  where title='[TEST] Potravinový průchod v42 · RIGUM'
    and planning_date=current_date
  limit 1;
  if v_route is not null and exists(
    select 1 from public.stock_movements_v13 movement
    where movement.reference_type='mobile_stock_request'
      and exists(
        select 1 from public.route_machine_visits visit
        where visit.route_plan_id=v_route and movement.reference_id like ('route_visit_' || visit.id || '_%')
      )
  ) then
    raise exception 'Předchozí test už obsahuje skladové pohyby. Nejdřív spusť bezpečný cleanup.';
  end if;

  if v_route is null then
    insert into public.route_plans(
      planning_date,title,vehicle_id,planned_employee_id,warehouse_id,planner_mode,optimization_provider,provider_status,
      start_latitude,start_longitude,end_latitude,end_longitude,return_to_start,stop_count,estimated_distance_km,
      estimated_drive_minutes,estimated_service_minutes,execution_status,assigned_at,planned_departure_time,route_payload
    ) values(
      current_date,'[TEST] Potravinový průchod v42 · RIGUM',v_vehicle,v_employee,1,'warehouse','heuristic','ready',
      48.9236612,17.0718631,48.9236612,17.0718631,false,2,4,8,45,'assigned',now(),localtime,
      jsonb_build_object('test_mode',true,'test_key','food-rigum-v42','food_guided_version',42,'vehicle_stock_location_id',v_vehicle_stock,'instructions','Pouze test v aplikaci. Na uvedená místa fyzicky nejezdit.')
    ) returning id into v_route;
  else
    delete from public.route_machine_visits where route_plan_id=v_route;
    delete from public.route_plan_stops where route_plan_id=v_route;
    update public.route_plans set
      vehicle_id=v_vehicle,planned_employee_id=v_employee,execution_status='assigned',assigned_at=now(),started_at=null,completed_at=null,
      stop_count=2,return_to_start=false,start_latitude=48.9236612,start_longitude=17.0718631,end_latitude=48.9236612,end_longitude=17.0718631,
      route_payload=jsonb_build_object('test_mode',true,'test_key','food-rigum-v42','food_guided_version',42,'vehicle_stock_location_id',v_vehicle_stock,'instructions','Pouze test v aplikaci. Na uvedená místa fyzicky nejezdit.')
    where id=v_route;
  end if;

  insert into public.route_plan_stops(
    route_plan_id,location_id,machine_id,stop_order,stop_kind,status,title,address_snapshot,city_snapshot,latitude,longitude,
    priority_snapshot,estimated_service_minutes,note
  ) values
    (v_route,v_source_location,v_source_machine,1,'restock','planned','[TEST] RIGUM · doplnění a expirace','Nikam nejezdit · test v telefonu','Dubňany',48.9236612,17.0718631,'high',30,'Vyzkoušej záměnu, prošlou expiraci, doplnění z auta a doporučený přesun.'),
    (v_route,v_target_location,v_target_machine,2,'restock','planned','[TEST] RIGUM · doprodání','Nikam nejezdit · druhá testovací zastávka','Dubňany',48.9351000,17.1025000,'normal',15,'Cíl přesunu krátké expirace; podle testovacích prodejů se zde zboží doprodá rychleji.');

  raise notice 'Vytvořena zkušební trasa #% pro Michala, vozidlo #%.',v_route,v_vehicle;
end
$$;

commit;

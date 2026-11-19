-- Izolovana zkusebni trasa pro PDA. Automat je kopie realneho EV 90,
-- ale nema telemetricke napojeni a testovaci rezim neodepisuje skutecne
-- zasoby vozidla. Po testu lze vse odstranit cleanup skriptem.
begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_source_machine bigint := 70;
  v_test_machine bigint;
  v_route bigint;
  v_test_slot bigint;
  v_source_slot public.machine_planogram_slots%rowtype;
  v_location public.locations%rowtype;
  v_product record;
begin
  perform pg_advisory_xact_lock(hashtextextended('operator-mixed-spring-test-20261119',0));

  if not exists(select 1 from public.machines where id=v_source_machine and active is true) then
    raise exception 'Zdrojovy automat EV 90 neni aktivni.';
  end if;

  select id into v_test_machine from public.machines
  where serial_number='TEST-MIXED-SPRING-20261119' limit 1;

  if v_test_machine is null then
    insert into public.machines(
      location_id,name,machine_type,brand,model,serial_number,status,active,note,qr_token,
      sales_tracking_mode,stock_initialized_at,subsidy_default_amount,subsidy_default_basis,
      subsidy_default_partner,subsidy_default_enabled
    )
    select location_id,'[TEST] Sportisimo EV 90 · kopie',machine_type,brand,model,
      'TEST-MIXED-SPRING-20261119','ok',true,
      'Docasna izolovana kopie pro overeni vice druhu v jedne pruzine.',
      md5('TEST-MIXED-SPRING-20261119-'||clock_timestamp()::text),
      'telemetry',now(),subsidy_default_amount,subsidy_default_basis,
      subsidy_default_partner,subsidy_default_enabled
    from public.machines where id=v_source_machine
    returning id into v_test_machine;

    insert into public.machine_planogram_slots(
      machine_id,slot_code,product_name,product_sku,price_czk,capacity_units,current_units,fill_percent,
      active,sort_order,note,dex_price_czk,desired_units,expiry_date,telemetry_key,last_units,
      product_family,product_variant,planned_product_name,planned_product_sku,planned_price_czk,
      substitution_policy,allowed_substitutes,operator_instruction,customer_price_czk,
      subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,subsidy_note,
      settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,settlement_note,
      target_units,replenishment_mode,pending_product_id,pending_product_sku,pending_product_name,
      pending_price_czk,pending_change_effective_date,pending_change_note,changeover_old_units,
      changeover_new_units,changeover_started_at,pending_change_mode,customer_selection_code,
      primary_product_id,primary_product_sku,primary_product_name
    )
    select v_test_machine,slot_code,product_name,product_sku,price_czk,capacity_units,current_units,fill_percent,
      active,sort_order,note,dex_price_czk,desired_units,expiry_date,telemetry_key,last_units,
      product_family,product_variant,planned_product_name,planned_product_sku,planned_price_czk,
      substitution_policy,allowed_substitutes,operator_instruction,customer_price_czk,
      subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,subsidy_note,
      settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,settlement_note,
      target_units,replenishment_mode,pending_product_id,pending_product_sku,pending_product_name,
      pending_price_czk,pending_change_effective_date,pending_change_note,changeover_old_units,
      changeover_new_units,changeover_started_at,pending_change_mode,customer_selection_code,
      primary_product_id,primary_product_sku,primary_product_name
    from public.machine_planogram_slots where machine_id=v_source_machine and slot_code='42';

    insert into public.machine_planogram_slot_layers(
      planogram_slot_id,layer_order,product_id,product_sku,product_name,quantity,expiry_date,source
    )
    select target.id,layer.layer_order,layer.product_id,layer.product_sku,layer.product_name,
      layer.quantity,layer.expiry_date,'test_clone'
    from public.machine_planogram_slot_layers layer
    join public.machine_planogram_slots source on source.id=layer.planogram_slot_id and source.machine_id=v_source_machine
    join public.machine_planogram_slots target on target.machine_id=v_test_machine and target.slot_code=source.slot_code;
  end if;

  if exists(select 1 from public.route_machine_visits visit join public.route_plans route on route.id=visit.route_plan_id
            where route.route_payload->>'test_key'='mixed-spring-real-planogram-v1' and route.planning_date=current_date) then
    raise exception 'Testovaci trasa uz obsahuje navstevu; automaticky reset byl zastaven.';
  end if;

  update public.machine_planogram_slots
  set target_units=coalesce(current_units,0),desired_units=0
  where machine_id=v_test_machine;

  -- Volba 42 ma trvale zustat Porizek. Fyzicky jsou ale zepredu Mlska,
  -- Hamka a az vzadu Porizek. Tim overime dve prepnuti i navrat k cili.
  select * into strict v_source_slot from public.machine_planogram_slots
  where machine_id=v_test_machine and slot_code='42' for update;
  select id into strict v_test_slot from public.machine_planogram_slots
  where machine_id=v_test_machine and slot_code='42';
  delete from public.machine_planogram_slot_layers where planogram_slot_id=v_test_slot;

  update public.machine_planogram_slots slot
  set primary_product_id=primary_product.id,
      primary_product_sku=primary_product.sku,
      primary_product_name=primary_product.name,
      product_sku=front_product.sku,
      product_name=front_product.name,
      current_units=3,capacity_units=6,target_units=6,desired_units=3,fill_percent=50,
      expiry_date=current_date+3,
      planned_product_sku=null,planned_product_name=null,planned_price_czk=null,
      changeover_old_units=null,changeover_new_units=null,changeover_started_at=null,
      pending_product_id=null,pending_product_sku=null,pending_product_name=null,pending_price_czk=null,
      pending_change_effective_date=null,pending_change_note=null,pending_change_mode='sell_through',
      note='TEST: fyzicky Mlska 1 ks -> Hamka 1 ks -> Porizek 1 ks; hlavni Porizek.'
  from public.products primary_product, public.products front_product
  where slot.id=v_test_slot and primary_product.sku='SIMPLY-PORIZEK' and front_product.sku='SIMPLY-MLSKA';

  for v_product in
    select p.*,x.layer_order,x.quantity,x.expiry_date
    from (values
      (1,'SIMPLY-MLSKA'::text,1,current_date+3),
      (2,'SIMPLY-HAMKA'::text,1,current_date+4),
      (3,'SIMPLY-PORIZEK'::text,1,current_date+5)
    ) x(layer_order,sku,quantity,expiry_date)
    join public.products p on p.sku=x.sku
    order by x.layer_order
  loop
    insert into public.machine_planogram_slot_layers(
      planogram_slot_id,layer_order,product_id,product_sku,product_name,quantity,expiry_date,source
    ) values(v_test_slot,v_product.layer_order,v_product.id,v_product.sku,v_product.name,
      v_product.quantity,v_product.expiry_date,'test_fixture');
  end loop;

  select id into v_route from public.route_plans
  where planning_date=current_date and planned_employee_id=v_employee
    and route_payload->>'test_key'='mixed-spring-real-planogram-v1' limit 1;
  if v_route is null then
    insert into public.route_plans(
      planning_date,title,vehicle_id,planned_employee_id,warehouse_id,planner_mode,
      optimization_provider,provider_status,return_to_start,stop_count,estimated_distance_km,
      estimated_drive_minutes,estimated_service_minutes,execution_status,assigned_at,
      planned_departure_time,start_latitude,start_longitude,route_payload
    ) values(
      current_date,'[TEST] Více baget v jedné pružině · Sportisimo',6,v_employee,1,'warehouse',
      'heuristic','ready',false,1,0,0,35,'assigned',now(),localtime,49.0547,16.6445,
      jsonb_build_object(
        'test_mode',true,'isolated_stock',true,'temporary',true,
        'test_key','mixed-spring-real-planogram-v1','source_machine_id',v_source_machine,
        'test_machine_id',v_test_machine,
        'test_goal','Volba 42: Mlska -> Hamka -> Porizek; hlavni produkt zustava Porizek.',
        'test_vehicle_stock',jsonb_build_object(
          'SIMPLY-PORIZEK',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text),
          'SIMPLY-MLSKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+3)::text),
          'SIMPLY-HAMKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+4)::text),
          'SIMPLY-DEBRECIN',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text),
          'SIMPLY-SVACINKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text)
        )
      )
    ) returning id into v_route;
  else
    delete from public.route_plan_stops where route_plan_id=v_route;
    update public.route_plans set title='[TEST] Více baget v jedné pružině · Sportisimo',vehicle_id=6,
      warehouse_id=1,execution_status='assigned',assigned_at=now(),started_at=null,completed_at=null,
      stop_count=1,estimated_distance_km=0,estimated_drive_minutes=0,estimated_service_minutes=35,
      route_payload=route_payload||jsonb_build_object('test_mode',true,'isolated_stock',true,'test_machine_id',v_test_machine),
      updated_at=now()
    where id=v_route;
  end if;

  select * into strict v_location from public.locations where id=(select location_id from public.machines where id=v_test_machine);
  insert into public.route_plan_stops(
    route_plan_id,location_id,machine_id,stop_order,stop_kind,status,title,address_snapshot,
    city_snapshot,latitude,longitude,priority_snapshot,estimated_service_minutes,note
  ) values(
    v_route,v_location.id,v_test_machine,1,'restock','planned',
    '[TEST] Sportisimo · kopie EV 90',v_location.address,v_location.city,v_location.latitude,v_location.longitude,
    'high',35,'Izolovaný test · skutečný EV 90 ani zásoba vozidla se nemění.'
  );
end $$;

commit;
notify pgrst,'reload schema';

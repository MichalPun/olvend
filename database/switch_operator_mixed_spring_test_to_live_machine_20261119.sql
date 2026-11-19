-- Zkusebni trasa pouziva skutecny aktivni automat EV 90 (machine 70),
-- ale stav volby 42, vrstvy i zasoba vozidla jsou pouze v route_payload.
-- Potvrzeni v test_mode zapisuje prubeh navstevy, nikoli planogram,
-- telemetrii nebo skutecne skladove pohyby automatu a vozidla.
begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_live_machine bigint := 70;
  v_route bigint;
  v_location public.locations%rowtype;
  v_clone_ids bigint[];
begin
  perform pg_advisory_xact_lock(hashtextextended('operator-mixed-spring-test-20261119',0));

  if not exists(select 1 from public.machines where id=v_live_machine and active is true) then
    raise exception 'Skutecny automat EV 90 (machine 70) neni aktivni.';
  end if;

  -- Predchozi izolovany klon uz neni potreba. Trasa je docasna a uzivatel
  -- vyslovne pozaduje jeji nove vytvoreni nad skutecnym automatem.
  delete from public.route_plans
  where route_payload->>'test_key'='mixed-spring-real-planogram-v1';

  select coalesce(array_agg(id),'{}'::bigint[]) into v_clone_ids
  from public.machines where serial_number='TEST-MIXED-SPRING-20261119';

  delete from public.stock_locations
  where location_type='machine' and machine_id=any(v_clone_ids)
    and not exists(
      select 1 from public.stock_location_balances balance
      where balance.stock_location_id=stock_locations.id and balance.quantity_on_hand<>0
    );
  delete from public.machines where id=any(v_clone_ids);

  select * into strict v_location
  from public.locations
  where id=(select location_id from public.machines where id=v_live_machine);

  insert into public.route_plans(
    planning_date,title,vehicle_id,planned_employee_id,warehouse_id,planner_mode,
    optimization_provider,provider_status,return_to_start,stop_count,estimated_distance_km,
    estimated_drive_minutes,estimated_service_minutes,execution_status,assigned_at,
    planned_departure_time,start_latitude,start_longitude,route_payload
  ) values(
    current_date,'[TEST] Více baget v jedné pružině · skutečný EV 90',6,v_employee,1,'warehouse',
    'heuristic','ready',false,1,0,0,35,'assigned',now(),localtime,49.0547,16.6445,
    jsonb_build_object(
      'test_mode',true,
      'isolated_stock',true,
      'temporary',true,
      'test_key','mixed-spring-real-planogram-v1',
      'source_machine_id',v_live_machine,
      'live_machine_id',v_live_machine,
      'test_goal','Volba 42: Mlska -> Hamka -> Porizek; hlavni produkt zustava Porizek.',
      'test_food_slots',jsonb_build_object(
        '42',jsonb_build_object(
          'primary_product_sku','SIMPLY-PORIZEK',
          'product_sku','SIMPLY-MLSKA',
          'current_units',3,
          'capacity_units',6,
          'target_units',6,
          'desired_units',3,
          'substitution_policy','approved_list',
          'allowed_substitutes','SKU SIMPLY-PORIZEK, SKU SIMPLY-MLSKA, SKU SIMPLY-HAMKA, SKU SIMPLY-DEBRECIN, SKU SIMPLY-SVACINKA',
          'layers',jsonb_build_array(
            jsonb_build_object('sku','SIMPLY-MLSKA','quantity',1,'expiry_date',(current_date+3)::text),
            jsonb_build_object('sku','SIMPLY-HAMKA','quantity',1,'expiry_date',(current_date+4)::text),
            jsonb_build_object('sku','SIMPLY-PORIZEK','quantity',1,'expiry_date',(current_date+5)::text)
          )
        )
      ),
      'test_vehicle_stock',jsonb_build_object(
        'SIMPLY-PORIZEK',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text),
        'SIMPLY-MLSKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+3)::text),
        'SIMPLY-HAMKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+4)::text),
        'SIMPLY-DEBRECIN',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text),
        'SIMPLY-SVACINKA',jsonb_build_object('quantity',12,'expiry_date',(current_date+5)::text)
      )
    )
  ) returning id into v_route;

  insert into public.route_plan_stops(
    route_plan_id,location_id,machine_id,stop_order,stop_kind,status,title,address_snapshot,
    city_snapshot,latitude,longitude,priority_snapshot,estimated_service_minutes,note
  ) values(
    v_route,v_location.id,v_live_machine,1,'restock','planned',
    '[TEST] Sportisimo · EV 90',v_location.address,v_location.city,v_location.latitude,v_location.longitude,
    'high',35,'Test nad skutecnym automatem. Stav volby a zasoby jsou izolovane v trase; skutecny planogram ani sklad se nemeni.'
  );
end $$;

commit;
notify pgrst,'reload schema';

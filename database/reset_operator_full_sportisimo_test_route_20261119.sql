-- Plnohodnotna testovaci trasa jako pri skutecnem vyjezdu:
-- Blucina -> Sportisimo -> kava EV 85 -> potraviny EV 90.
-- Oba automaty jsou skutecne; test_mode izoluje skladove a planogramove zapisy.
begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_route bigint;
  v_location public.locations%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('operator-full-sportisimo-test-20261119',0));

  if not exists(select 1 from public.machines where id=65 and active is true) then
    raise exception 'Kavovy automat EV 85 neni aktivni.';
  end if;
  if not exists(select 1 from public.machines where id=70 and active is true) then
    raise exception 'Potravinovy automat EV 90 neni aktivni.';
  end if;

  delete from public.route_plans
  where route_payload->>'test_key' in ('mixed-spring-real-planogram-v1','operator-full-sportisimo-v2')
    and planning_date=current_date;

  select * into strict v_location from public.locations where id=58;

  insert into public.route_plans(
    planning_date,title,vehicle_id,planned_employee_id,warehouse_id,planner_mode,
    optimization_provider,provider_status,start_latitude,start_longitude,end_latitude,end_longitude,
    return_to_start,stop_count,estimated_distance_km,estimated_drive_minutes,
    estimated_service_minutes,execution_status,assigned_at,planned_departure_time,route_payload
  ) values(
    current_date,'[TEST] Blučina → Sportisimo · EV 85 + EV 90',6,v_employee,1,'warehouse',
    'google_routes_matrix','ready',49.0531848,16.6270199,v_location.latitude,v_location.longitude,
    false,2,170,110,55,'assigned',now(),localtime,
    jsonb_build_object(
      'test_mode',true,
      'isolated_stock',true,
      'temporary',true,
      'test_key','operator-full-sportisimo-v2',
      'planned_employee_name','Michal Punčochář',
      'vehicle_plate','3BU9736',
      'instructions','Plnohodnotný průchod skutečnou trasou a oběma automaty. Po schválení se trasa smaže.',
      'test_food_slots_mode','overlay',
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
  ) values
    (v_route,v_location.id,65,1,'restock','planned','Sportisimo · EV 85 · Luce X2 I/E',
      v_location.address,v_location.city,v_location.latitude,v_location.longitude,'high',25,
      'První automat na lokalitě · kávový.'),
    (v_route,v_location.id,70,2,'restock','planned','Sportisimo · EV 90 · Saphirh 10',
      v_location.address,v_location.city,v_location.latitude,v_location.longitude,'high',30,
      'Druhý automat na lokalitě · potravinový, celý skutečný planogram.');
end $$;

commit;
notify pgrst,'reload schema';

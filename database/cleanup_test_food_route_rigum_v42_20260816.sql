-- Vrátí všechny skladové pohyby z izolovaného testu a odstraní pouze testovací data.
-- Skutečné produkty, vozidlo a živý automat Rigum EV 100 zůstávají nedotčené.

begin;

do $$
declare
  v_route public.route_plans%rowtype;
  v_visit_ids bigint[] := '{}'::bigint[];
  v_source_machine bigint;
  v_target_machine bigint;
  v_source_location bigint;
  v_target_location bigint;
  v_source_stock bigint;
  v_target_stock bigint;
  v_vehicle_stock bigint;
  v_reverse_rows jsonb;
  v_rollback_reference text;
begin
  select * into v_route
  from public.route_plans
  where title='[TEST] Potravinový průchod v42 · RIGUM'
    and route_payload->>'test_key'='food-rigum-v42'
  order by id desc
  limit 1
  for update;
  if not found then
    raise notice 'Zkušební trasa RIGUM v42 už neexistuje.';
    return;
  end if;
  if v_route.planned_employee_id <> 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
     or v_route.vehicle_id <> 1
     or coalesce((v_route.route_payload->>'test_mode')::boolean,false) is not true then
    raise exception 'Nalezená trasa neodpovídá bezpečně označenému testu.';
  end if;

  select id into v_source_machine from public.machines where qr_token='test-rigum-food-v42-source' limit 1;
  select id into v_target_machine from public.machines where qr_token='test-rigum-food-v42-target' limit 1;
  if v_source_machine is null or v_target_machine is null then
    raise exception 'Testovací automaty nebyly nalezeny; cleanup se zastavil před změnou zásob.';
  end if;
  if v_source_machine=80 or v_target_machine=80 then
    raise exception 'Bezpečnostní kontrola: test nesmí odkazovat na živý Rigum EV 100.';
  end if;

  select location_id into v_source_location from public.machines where id=v_source_machine;
  select location_id into v_target_location from public.machines where id=v_target_machine;
  select id into v_source_stock from public.stock_locations where location_type='machine' and machine_id=v_source_machine limit 1;
  select id into v_target_stock from public.stock_locations where location_type='machine' and machine_id=v_target_machine limit 1;
  select id into v_vehicle_stock from public.stock_locations where location_type='vehicle' and vehicle_id=1 and active is true order by id limit 1;
  if v_vehicle_stock is null then
    raise exception 'Sklad vozidla #1 nebyl nalezen; cleanup se zastavil.';
  end if;

  select coalesce(array_agg(id order by id),'{}'::bigint[]) into v_visit_ids
  from public.route_machine_visits
  where route_plan_id=v_route.id;
  v_rollback_reference := 'test-food-rigum-v42-rollback:' || v_route.id;

  if not exists(
    select 1 from public.stock_movements_v13
    where reference_type='mobile_stock_request' and reference_id=v_rollback_reference
  ) then
    select jsonb_agg(
      jsonb_build_object(
        'product_id',movement.product_id,
        'batch_id',movement.batch_id,
        'from_stock_location_id',movement.to_stock_location_id,
        'to_stock_location_id',movement.from_stock_location_id,
        'movement_type','adjustment',
        'quantity_base_units',movement.quantity_base_units,
        'reference_type','mobile_stock_request',
        'reference_id',v_rollback_reference,
        'note','Automatický rollback izolovaného testu RIGUM v42 · původní pohyb #' || movement.id
      ) order by movement.id desc
    ) into v_reverse_rows
    from public.stock_movements_v13 movement
    where movement.reference_type='mobile_stock_request'
      and exists(
        select 1 from unnest(v_visit_ids) visit_id
        where movement.reference_id like ('route_visit_' || visit_id || '_%')
      );
    if v_reverse_rows is not null and jsonb_array_length(v_reverse_rows)>0 then
      perform public.apply_stock_movements_v13(v_reverse_rows);
    end if;
  end if;

  if exists(
    select 1
    from public.stock_movements_v13 movement
    where (
      movement.reference_id=v_rollback_reference
      or exists(
        select 1 from unnest(v_visit_ids) visit_id
        where movement.reference_type='mobile_stock_request'
          and movement.reference_id like ('route_visit_' || visit_id || '_%')
      )
    )
    group by movement.product_id,movement.batch_id
    having abs(sum(
      case when movement.to_stock_location_id=v_vehicle_stock then movement.quantity_base_units else 0 end
      - case when movement.from_stock_location_id=v_vehicle_stock then movement.quantity_base_units else 0 end
    ))>0.0001
  ) then
    raise exception 'Kontrola rollbacku zjistila nenulový testovací rozdíl ve vozidle. Data nebyla odstraněna.';
  end if;

  delete from public.route_vehicle_waste_items where route_plan_id=v_route.id;
  if to_regclass('public.inventory_audits') is not null then
    delete from public.inventory_audits where source_route_plan_id=v_route.id;
  end if;
  if to_regclass('public.route_distance_reports') is not null then
    execute 'delete from public.route_distance_reports where route_plan_id=$1' using v_route.id;
  end if;

  delete from public.route_machine_visits where route_plan_id=v_route.id;
  delete from public.route_plans where id=v_route.id;

  delete from public.stock_movements_v13 movement
  where movement.reference_id=v_rollback_reference
    or exists(
      select 1 from unnest(v_visit_ids) visit_id
      where movement.reference_type='mobile_stock_request'
        and movement.reference_id like ('route_visit_' || visit_id || '_%')
    );

  delete from public.telemetry_sales_events
  where provider='test-food-v42' and machine_id in(v_source_machine,v_target_machine);
  delete from public.stock_location_balances where stock_location_id in(v_source_stock,v_target_stock);
  delete from public.stock_locations where id in(v_source_stock,v_target_stock);
  delete from public.inventory_batches
  where lot_code in('TEST-RIGUM-V42-SHORT','TEST-RIGUM-V42-EXPIRED','TEST-RIGUM-V42-TARGET')
    and note='Pouze izolovaný test FOOD V42';
  delete from public.machines where id in(v_source_machine,v_target_machine);
  delete from public.locations where id in(v_source_location,v_target_location)
    and name in('[TEST] RIGUM · nový potravinový průchod','[TEST] RIGUM · místo pro doprodání');

  if exists(select 1 from public.route_plans where id=v_route.id)
     or exists(select 1 from public.machines where id in(v_source_machine,v_target_machine)) then
    raise exception 'Testovací data se nepodařilo odstranit kompletně.';
  end if;
  raise notice 'Testovací trasa #% byla vrácena a odstraněna; čistý rozdíl vozidla je nula.',v_route.id;
end
$$;

commit;

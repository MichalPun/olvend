begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_warehouse bigint;
  v_stock bigint;
  v_location bigint;
  v_machine bigint;
  v_route bigint;
  v_instruction bigint;
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
  select id into v_warehouse
  from public.warehouses
  where code = 'TEST-PDA'
  limit 1;

  if v_warehouse is null then
    insert into public.warehouses(name, code, type, city, address, note, active, latitude, longitude)
    values (
      '[TEST] Izolovaný sklad PDA',
      'TEST-PDA',
      'warehouse',
      'Blučina',
      'Pouze virtuální sklad – nikam nejezdit',
      'Izolované zásoby pro průchod aplikací OLVEND Operátor.',
      false,
      49.0547,
      16.6445
    )
    returning id into v_warehouse;
  end if;

  select id into v_stock
  from public.stock_locations
  where warehouse_id = v_warehouse and location_type = 'warehouse'
  limit 1;

  if v_stock is null then
    insert into public.stock_locations(location_type, name, warehouse_id, active, note)
    values ('warehouse', '[TEST] Sklad PDA', v_warehouse, true, 'Pouze izolovaná zkušební trasa.')
    returning id into v_stock;
  else
    update public.stock_locations set active = true, updated_at = now() where id = v_stock;
  end if;

  select id into v_location
  from public.locations
  where name = '[TEST] OLVEND Operátor · PDA'
  limit 1;

  if v_location is null then
    insert into public.locations(name, city, address, customer_name, active, route_note, latitude, longitude)
    values (
      '[TEST] OLVEND Operátor · PDA',
      'Blučina',
      'Virtuální testovací zastávka – nikam nejezdit',
      'OLVEND TEST',
      true,
      'Pouze pro krokové ověření aplikace na PDA.',
      49.0547,
      16.6445
    )
    returning id into v_location;
  end if;

  select id into v_machine
  from public.machines
  where note like '%OPERATOR_PDA_TEST_V1%'
  limit 1;

  if v_machine is null then
    insert into public.machines(
      location_id, name, machine_type, brand, model, serial_number,
      status, active, note, qr_token, evidence_number, sales_tracking_mode
    ) values (
      v_location,
      '[TEST] Luce X2 · OLVEND Operátor',
      'coffee',
      'Rheavendors',
      'Luce X2',
      'TEST-OPERATOR-PDA-0001',
      'ok',
      true,
      'OPERATOR_PDA_TEST_V1 · izolovaný automat',
      'operator-pda-test-v1',
      9991,
      'telemetry'
    ) returning id into v_machine;
  else
    update public.machines
    set location_id = v_location, active = true, status = 'ok', sales_tracking_mode = 'telemetry'
    where id = v_machine;
  end if;

  insert into public.machine_external_links(machine_id, provider, external_machine_id, telemetry_enabled, note)
  values (v_machine, 'test', 'OPERATOR-PDA-TEST-9991', true, 'Izolovaná telemetrie pro průchod PDA')
  on conflict(provider, external_machine_id) do update
  set machine_id = excluded.machine_id, telemetry_enabled = true;

  insert into public.products(name, sku, product_category, usage_type, base_unit, vat_rate, active, note, can_be_used_in_recipe)
  values ('[TEST] Káva PDA 1 kg', 'TEST-PDA-COFFEE', 'ingredient', 'recipe_consumption', 'kg', 12, true, 'Pouze izolovaná zkušební trasa', true)
  on conflict(sku) do update set active = true
  returning id into v_coffee;

  insert into public.products(name, sku, product_category, usage_type, base_unit, vat_rate, active, note, can_be_used_in_recipe)
  values ('[TEST] Mléko PDA 1 kg', 'TEST-PDA-MILK', 'ingredient', 'recipe_consumption', 'kg', 12, true, 'Pouze izolovaná zkušební trasa', true)
  on conflict(sku) do update set active = true
  returning id into v_milk;

  insert into public.products(name, sku, product_category, usage_type, base_unit, vat_rate, active, note, can_be_used_in_recipe)
  values ('[TEST] Čokoláda PDA 1 kg', 'TEST-PDA-COCOA', 'ingredient', 'recipe_consumption', 'kg', 12, true, 'Pouze izolovaná zkušební trasa', true)
  on conflict(sku) do update set active = true
  returning id into v_cocoa;

  insert into public.products(name, sku, product_category, usage_type, base_unit, vat_rate, active, note, can_be_used_in_recipe)
  values ('[TEST] Kelímek PDA 180 ml', 'TEST-PDA-CUPS', 'consumable', 'recipe_consumption', 'ks', 21, true, 'Pouze izolovaná zkušební trasa', true)
  on conflict(sku) do update set active = true
  returning id into v_cups;

  insert into public.product_packages(product_id, package_name, units_per_package, is_default, active)
  select p.id, case when p.id = v_cups then 'balení 50 ks' else 'balení 1 kg' end,
         case when p.id = v_cups then 50 else 1 end, true, true
  from (values (v_coffee), (v_milk), (v_cocoa), (v_cups)) p(id)
  where not exists (
    select 1 from public.product_packages package
    where package.product_id = p.id and package.is_default is true
  );

  select id into v_z1 from public.machine_coffee_containers where machine_id = v_machine and container_code = 'Z1';
  if v_z1 is null then
    insert into public.machine_coffee_containers(machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active)
    values (v_machine, 'Z1', v_coffee, 'TEST-PDA-COFFEE', '[TEST] Káva PDA 1 kg', 3000, 1000, 'g', 1000, 'g', 1000, 10, true) returning id into v_z1;
    insert into public.machine_coffee_containers(machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active)
    values (v_machine, 'Z2', v_milk, 'TEST-PDA-MILK', '[TEST] Mléko PDA 1 kg', 2000, 500, 'g', 1000, 'g', 1000, 20, true) returning id into v_z2;
    insert into public.machine_coffee_containers(machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active)
    values (v_machine, 'Z3', v_cocoa, 'TEST-PDA-COCOA', '[TEST] Čokoláda PDA 1 kg', 2000, 1000, 'g', 1000, 'g', 1000, 30, true) returning id into v_z3;
    insert into public.machine_coffee_containers(machine_id, container_code, product_id, product_sku, product_name, capacity_quantity, current_quantity, unit, refill_package_quantity, refill_package_unit, min_refill_quantity, sort_order, active)
    values (v_machine, 'Z4', v_cups, 'TEST-PDA-CUPS', '[TEST] Kelímek PDA 180 ml', 300, 200, 'ks', 50, 'ks', 50, 40, true) returning id into v_z4;
  else
    select id into v_z2 from public.machine_coffee_containers where machine_id = v_machine and container_code = 'Z2';
    select id into v_z3 from public.machine_coffee_containers where machine_id = v_machine and container_code = 'Z3';
    select id into v_z4 from public.machine_coffee_containers where machine_id = v_machine and container_code = 'Z4';
    update public.machine_coffee_containers
    set current_quantity = case container_code when 'Z1' then 1000 when 'Z2' then 500 when 'Z3' then 1000 else 200 end,
        active = true,
        updated_at = now()
    where machine_id = v_machine;
  end if;

  select id into v_b1 from public.machine_coffee_buttons where machine_id = v_machine and selection_code = '1';
  if v_b1 is null then
    insert into public.machine_coffee_buttons(machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, sort_order, active)
    values (v_machine, '1', v_coffee, 'TEST-PDA-ESPRESSO', 'Espresso · TEST', 15, 15, 10, true) returning id into v_b1;
    insert into public.machine_coffee_buttons(machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, sort_order, active)
    values (v_machine, '7', v_coffee, 'TEST-PDA-CAPPUCCINO', 'Cappuccino · TEST', 20, 20, 20, true) returning id into v_b2;
    insert into public.machine_coffee_buttons(machine_id, selection_code, product_id, product_sku, product_name, sale_price_czk, customer_price_czk, sort_order, active)
    values (v_machine, '12', v_cocoa, 'TEST-PDA-CHOCOLATE', 'Horká čokoláda · TEST', 20, 20, 30, true) returning id into v_b3;
  else
    select id into v_b2 from public.machine_coffee_buttons where machine_id = v_machine and selection_code = '7';
    select id into v_b3 from public.machine_coffee_buttons where machine_id = v_machine and selection_code = '12';
  end if;

  if not exists (select 1 from public.machine_coffee_recipe_items where machine_id = v_machine) then
    insert into public.machine_coffee_recipe_items(machine_id, coffee_button_id, coffee_container_id, container_code, ingredient_name, quantity_per_vend, unit, sort_order, active, product_id)
    values
      (v_machine, v_b1, v_z1, 'Z1', 'Káva', 8, 'g', 10, true, v_coffee),
      (v_machine, v_b1, v_z4, 'Z4', 'Kelímek', 1, 'ks', 20, true, v_cups),
      (v_machine, v_b2, v_z1, 'Z1', 'Káva', 8, 'g', 10, true, v_coffee),
      (v_machine, v_b2, v_z2, 'Z2', 'Mléko', 14, 'g', 20, true, v_milk),
      (v_machine, v_b2, v_z4, 'Z4', 'Kelímek', 1, 'ks', 30, true, v_cups),
      (v_machine, v_b3, v_z3, 'Z3', 'Čokoláda', 22, 'g', 10, true, v_cocoa),
      (v_machine, v_b3, v_z4, 'Z4', 'Kelímek', 1, 'ks', 20, true, v_cups);
  end if;

  delete from public.stock_location_balances
  where stock_location_id = v_stock
    and product_id in (v_coffee, v_milk, v_cocoa, v_cups);

  insert into public.stock_location_balances(stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity)
  values
    (v_stock, v_coffee, null, 10, 0),
    (v_stock, v_milk, null, 10, 0),
    (v_stock, v_cocoa, null, 10, 0),
    (v_stock, v_cups, null, 500, 0);

  if not exists (
    select 1 from public.telemetry_sales_events
    where provider = 'test' and source_event_key = 'OPERATOR-PDA-TEST-CASH-260'
  ) then
    insert into public.telemetry_sales_events(provider, machine_id, selection_code, product_name, quantity, cash_quantity, cashless_quantity, unit_price_czk, total_amount_czk, cash_amount_czk, cashless_amount_czk, source_event_at, source_event_key, source_location_name, source_machine_name)
    values ('test', v_machine, '7', 'Cappuccino · TEST', 13, 13, 0, 20, 260, 260, 0, now() - interval '2 hours', 'OPERATOR-PDA-TEST-CASH-260', '[TEST] OLVEND Operátor · PDA', '[TEST] Luce X2');
  end if;

  select id into v_route
  from public.route_plans
  where planning_date = current_date
    and route_payload->>'test_key' = 'operator-pda-v1'
  limit 1;

  if v_route is null then
    insert into public.route_plans(
      planning_date, title, vehicle_id, planned_employee_id, warehouse_id,
      planner_mode, optimization_provider, provider_status, return_to_start,
      stop_count, estimated_distance_km, estimated_drive_minutes,
      estimated_service_minutes, execution_status, assigned_at,
      planned_departure_time, start_latitude, start_longitude, route_payload
    ) values (
      current_date,
      '[TEST] OLVEND Operátor · krok za krokem',
      null,
      v_employee,
      v_warehouse,
      'warehouse',
      'heuristic',
      'ready',
      false,
      1,
      0,
      0,
      25,
      'assigned',
      now(),
      localtime,
      49.0547,
      16.6445,
      jsonb_build_object(
        'test_mode', true,
        'test_key', 'operator-pda-v1',
        'stock_source_mode', 'warehouse_direct',
        'stock_source_name', '[TEST] Izolovaný sklad PDA',
        'instructions', 'Pouze test v aplikaci. Na uvedené místo fyzicky nejezděte.'
      )
    ) returning id into v_route;
  else
    update public.route_plans
    set title = '[TEST] OLVEND Operátor · krok za krokem',
        vehicle_id = null,
        planned_employee_id = v_employee,
        warehouse_id = v_warehouse,
        execution_status = 'assigned',
        assigned_at = now(),
        started_at = null,
        completed_at = null,
        stop_count = 1,
        estimated_distance_km = 0,
        estimated_drive_minutes = 0,
        estimated_service_minutes = 25,
        route_payload = jsonb_build_object(
          'test_mode', true,
          'test_key', 'operator-pda-v1',
          'stock_source_mode', 'warehouse_direct',
          'stock_source_name', '[TEST] Izolovaný sklad PDA',
          'instructions', 'Pouze test v aplikaci. Na uvedené místo fyzicky nejezděte.'
        ),
        updated_at = now()
    where id = v_route;
    delete from public.route_machine_visits where route_plan_id = v_route;
    delete from public.route_plan_stops where route_plan_id = v_route;
  end if;

  insert into public.route_plan_stops(
    route_plan_id, location_id, machine_id, stop_order, stop_kind, status,
    title, address_snapshot, city_snapshot, latitude, longitude,
    estimated_service_minutes, note
  ) values (
    v_route,
    v_location,
    v_machine,
    1,
    'restock',
    'planned',
    '[TEST] Luce X2 · průchod PDA',
    'Virtuální testovací zastávka – nikam nejezdit',
    'Blučina',
    49.0547,
    16.6445,
    25,
    'Vyzkoušejte celý postup. Všechny zásoby i automat jsou izolované testovací záznamy.'
  );

  insert into public.daily_instructions(
    title, message, target_type, target_employee_id, valid_from, valid_to,
    is_persistent, priority, requires_acknowledgement, is_active,
    created_by_employee_id, attachment_url, attachment_label,
    instruction_type, instruction_payload, source_reference
  ) values (
    'Test dnešní trasy na PDA',
    'Projděte dnešní zkušební trasu krok za krokem. Jde pouze o izolovaný test v aplikaci; nikam fyzicky nejezděte.',
    'employee',
    v_employee,
    current_date,
    current_date,
    false,
    'important',
    true,
    true,
    v_employee,
    './assets/instructions/pokyn-dne-test-2026-11-17.pdf',
    'Pokyn ke zkušební trase na PDA',
    'signed_document',
    jsonb_build_object(
      'requiresSignature', true,
      'documentVersion', 'PDA-TEST-1.0',
      'documentSha256', '094f8423393ae1bf1ce51c4d5e18d9b220b98a911793a54eb241114f706bd561',
      'previewPages', jsonb_build_array('./assets/instructions/pokyn-dne-test-2026-11-17-page-1-hires.png'),
      'pageCount', 1,
      'warningText', 'Testovací potvrzení se ukládá stejně jako ostrý pokyn.'
    ),
    'operator-pda-test-route:' || current_date::text || ':' || v_employee::text
  )
  on conflict (source_reference) where source_reference is not null do update
  set title = excluded.title,
      message = excluded.message,
      target_employee_id = excluded.target_employee_id,
      valid_from = excluded.valid_from,
      valid_to = excluded.valid_to,
      priority = excluded.priority,
      requires_acknowledgement = excluded.requires_acknowledgement,
      is_active = excluded.is_active,
      attachment_url = excluded.attachment_url,
      attachment_label = excluded.attachment_label,
      instruction_type = excluded.instruction_type,
      instruction_payload = excluded.instruction_payload,
      updated_at = now()
  returning id into v_instruction;

  delete from public.instruction_acknowledgements
  where instruction_id = v_instruction and employee_id = v_employee;

  delete from public.instruction_events
  where instruction_id = v_instruction and employee_id = v_employee;
end;
$$;

commit;

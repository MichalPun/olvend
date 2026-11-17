begin;

do $$
declare
  v_employee uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_route bigint;
  v_instruction bigint;
  v_vehicle_stock bigint;
  v_product_ids jsonb;
  v_snapshot jsonb;
begin
  if (
    select count(*)
    from (values (65::bigint), (70::bigint)) expected(machine_id)
    join public.machines m on m.id = expected.machine_id and m.active is true
    where exists (
      select 1 from public.telemetry_sales_events t
      where t.machine_id = m.id and t.source_event_at >= now() - interval '24 hours'
    )
  ) <> 2 then
    raise exception 'EV 85 nebo EV 90 nemá čerstvou telemetrii za posledních 24 hodin. Test nebyl vytvořen.';
  end if;

  if exists (
    select 1 from public.route_plans
    where planned_employee_id = v_employee
      and planning_date = current_date
      and execution_status not in ('cancelled', 'completed')
      and coalesce((route_payload->>'test_mode')::boolean, false) is not true
  ) then
    raise exception 'Na dnešek už existuje ostrá aktivní trasa. Test nebyl vytvořen.';
  end if;

  select id into v_vehicle_stock
  from public.stock_locations
  where vehicle_id = 6 and location_type = 'vehicle' and active is true
  limit 1;

  select coalesce(jsonb_agg(distinct product_id), '[]'::jsonb)
  into v_product_ids
  from (
    select c.product_id
    from public.machine_coffee_containers c
    where c.machine_id = 65 and c.product_id is not null
    union
    select p.id
    from public.machine_planogram_slots s
    join public.products p on p.sku in (s.product_sku, s.planned_product_sku)
    where s.machine_id = 70
  ) products;

  select jsonb_build_object(
    'captured_at', now(),
    'coffee_machine_id', 65,
    'food_machine_id', 70,
    'vehicle_id', 6,
    'vehicle_stock_location_id', v_vehicle_stock,
    'product_ids', v_product_ids,
    'coffee_containers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'current_quantity', c.current_quantity,
        'physical_counted_at', c.physical_counted_at,
        'physical_count_source', c.physical_count_source,
        'physical_count_visit_item_id', c.physical_count_visit_item_id
      ) order by c.id)
      from public.machine_coffee_containers c
      where c.machine_id = 65
    ), '[]'::jsonb),
    'food_slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'current_units', s.current_units,
        'last_units', s.last_units,
        'fill_percent', s.fill_percent,
        'expiry_date', s.expiry_date,
        'product_sku', s.product_sku,
        'product_name', s.product_name,
        'planned_product_sku', s.planned_product_sku,
        'planned_product_name', s.planned_product_name
      ) order by s.id)
      from public.machine_planogram_slots s
      where s.machine_id = 70
    ), '[]'::jsonb),
    'vehicle_balances', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', b.product_id,
        'batch_id', b.batch_id,
        'quantity_on_hand', b.quantity_on_hand,
        'reserved_quantity', b.reserved_quantity
      ) order by b.product_id, b.batch_id nulls first)
      from public.stock_location_balances b
      where b.stock_location_id = v_vehicle_stock
        and b.product_id in (
          select value::text::bigint from jsonb_array_elements(v_product_ids)
        )
    ), '[]'::jsonb)
  ) into v_snapshot;

  select id into v_route
  from public.route_plans
  where planning_date = current_date
    and planned_employee_id = v_employee
    and route_payload->>'test_key' = 'operator-pda-real-machines-v1'
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
      '[TEST] OLVEND Operátor · Sportisimo · káva + potraviny',
      6,
      v_employee,
      1,
      'warehouse',
      'heuristic',
      'ready',
      false,
      2,
      170,
      110,
      45,
      'assigned',
      now(),
      localtime,
      49.0547,
      16.6445,
      jsonb_build_object(
        'test_mode', true,
        'temporary', true,
        'test_key', 'operator-pda-real-machines-v1',
        'vehicle_plate', '3BU9736',
        'planned_employee_name', 'Michal Punčochář',
        'instructions', 'Dočasný test na reálných automatech Sportisimo EV 85 a EV 90. Po zkoušce obnovit snapshot a trasu odstranit.',
        'pretest_snapshot', v_snapshot
      )
    ) returning id into v_route;
  else
    if exists (select 1 from public.route_machine_visits where route_plan_id = v_route) then
      raise exception 'Dnešní testovací trasa už obsahuje návštěvy. Automatický reset byl zastaven kvůli ochraně reálných dat.';
    end if;
    delete from public.route_plan_stops where route_plan_id = v_route;
    update public.route_plans
    set title = '[TEST] OLVEND Operátor · Sportisimo · káva + potraviny',
        vehicle_id = 6,
        warehouse_id = 1,
        execution_status = 'assigned',
        assigned_at = now(),
        started_at = null,
        completed_at = null,
        stop_count = 2,
        estimated_distance_km = 170,
        estimated_drive_minutes = 110,
        estimated_service_minutes = 45,
        route_payload = jsonb_build_object(
          'test_mode', true,
          'temporary', true,
          'test_key', 'operator-pda-real-machines-v1',
          'vehicle_plate', '3BU9736',
          'planned_employee_name', 'Michal Punčochář',
          'instructions', 'Dočasný test na reálných automatech Sportisimo EV 85 a EV 90. Po zkoušce obnovit snapshot a trasu odstranit.',
          'pretest_snapshot', v_snapshot
        ),
        updated_at = now()
    where id = v_route;
  end if;

  insert into public.route_plan_stops(
    route_plan_id, location_id, machine_id, stop_order, stop_kind, status,
    title, address_snapshot, city_snapshot, latitude, longitude,
    priority_snapshot, service_window_snapshot, estimated_service_minutes, note
  )
  select
    v_route,
    m.location_id,
    m.id,
    selected.stop_order,
    'restock',
    'planned',
    '[TEST] EV ' || m.evidence_number || ' · ' || m.name,
    l.address,
    l.city,
    l.latitude,
    l.longitude,
    'high',
    null,
    case when selected.stop_order = 1 then 25 else 30 end,
    'DOČASNÝ TEST NA REÁLNÉM AUTOMATU · po testu obnovit snapshot'
  from (values (1, 65::bigint), (2, 70::bigint)) selected(stop_order, machine_id)
  join public.machines m on m.id = selected.machine_id
  join public.locations l on l.id = m.location_id
  order by selected.stop_order;

  insert into public.daily_instructions(
    title, message, target_type, target_employee_id, valid_from, valid_to,
    is_persistent, priority, requires_acknowledgement, is_active,
    created_by_employee_id, attachment_url, attachment_label,
    instruction_type, instruction_payload, source_reference
  ) values (
    'Test dnešní trasy na PDA',
    'Projděte zkušební trasu Sportisimo krok za krokem. Trasa používá reálný kávový EV 85 a potravinový EV 90 a po dokončení bude odstraněna.',
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
      'documentVersion', 'PDA-REAL-TEST-1.0',
      'documentSha256', '094f8423393ae1bf1ce51c4d5e18d9b220b98a911793a54eb241114f706bd561',
      'previewPages', jsonb_build_array('./assets/instructions/pokyn-dne-test-2026-11-17-page-1-hires.png'),
      'pageCount', 1,
      'warningText', 'Testovací potvrzení se ukládá stejně jako ostrý pokyn.'
    ),
    'operator-pda-real-test-route:' || current_date::text || ':' || v_employee::text
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

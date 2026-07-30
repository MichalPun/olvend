-- Ukázkové trasy pro poradu s operátorkami 30. 7. 2026.
-- Každá trasa obsahuje jeden kávový a jeden potravinový automat.
-- Trasy jsou pouze přiřazené; skladové pohyby vzniknou až při práci operátorky.

do $$
declare
  v_route_id bigint;
  v_existing_count integer;
  v_created_count integer := 0;
  r record;
begin
  for r in
    select *
    from (values
      (
        '9133f82b-89a6-4581-955c-d2138b947a8d'::uuid,
        'Kristýna Dvořáková'::text,
        3::bigint,
        8::bigint,
        14::bigint,
        1::bigint
      ),
      (
        '7f724803-eb2e-44fc-afba-0b87b82cdbc5'::uuid,
        'Michaela Nerudová'::text,
        2::bigint,
        40::bigint,
        72::bigint,
        6::bigint
      ),
      (
        'f1a8c845-b25e-437d-9d46-c7c79280db98'::uuid,
        'Sandra Svobodová'::text,
        5::bigint,
        60::bigint,
        60::bigint,
        58::bigint
      )
    ) as x(employee_id, employee_name, vehicle_id, location_id, coffee_machine_id, food_machine_id)
  loop
    select count(*) into v_existing_count
    from public.route_plans
    where planning_date = '2026-07-30'::date
      and planned_employee_id = r.employee_id
      and route_payload ->> 'demo_key' = 'operator-meeting-20260730';

    if v_existing_count = 0 then
      insert into public.route_plans (
        planning_date,
        title,
        vehicle_id,
        planned_employee_id,
        warehouse_id,
        planner_mode,
        optimization_provider,
        provider_status,
        return_to_start,
        stop_count,
        estimated_distance_km,
        estimated_drive_minutes,
        estimated_service_minutes,
        route_payload,
        execution_status,
        assigned_at
      )
      values (
        '2026-07-30'::date,
        'UKÁZKA – PORADA · ' || r.employee_name || ' · káva + potraviny',
        r.vehicle_id,
        r.employee_id,
        1,
        'warehouse',
        'heuristic',
        'ready',
        true,
        2,
        0,
        0,
        10,
        jsonb_build_object(
          'demo_route', true,
          'demo_key', 'operator-meeting-20260730',
          'demo_notice', 'Ukázková trasa pro poradu. Jeden kávový a jeden potravinový automat.',
          'route_mode', 'training',
          'planned_employee_id', r.employee_id,
          'planned_employee_name', r.employee_name,
          'generated_at', now()
        ),
        'assigned',
        now()
      )
      returning id into v_route_id;

      insert into public.route_plan_stops (
        route_plan_id,
        location_id,
        machine_id,
        stop_order,
        stop_kind,
        status,
        title,
        address_snapshot,
        city_snapshot,
        latitude,
        longitude,
        priority_snapshot,
        estimated_service_minutes,
        note
      )
      select
        v_route_id,
        l.id,
        m.id,
        stop_data.stop_order,
        'manual',
        'planned',
        m.name,
        l.address,
        l.city,
        l.latitude,
        l.longitude,
        'normal',
        5,
        'UKÁZKA – PORADA · ' ||
          case when stop_data.stop_order = 1 then 'kávový automat' else 'potravinový automat' end ||
          ' · EV ' || m.evidence_number
      from (values
        (1, r.coffee_machine_id),
        (2, r.food_machine_id)
      ) as stop_data(stop_order, machine_id)
      join public.machines m on m.id = stop_data.machine_id
      join public.locations l on l.id = m.location_id
      where l.id = r.location_id;

      if (select count(*) from public.route_plan_stops where route_plan_id = v_route_id) <> 2 then
        raise exception 'Ukázková trasa % nemá přesně dvě zastávky.', v_route_id;
      end if;

      v_created_count := v_created_count + 1;
    end if;
  end loop;

  if (
    select count(*)
    from public.route_plans
    where planning_date = '2026-07-30'::date
      and route_payload ->> 'demo_key' = 'operator-meeting-20260730'
  ) <> 3 then
    raise exception 'Očekávány tři ukázkové trasy pro poradu.';
  end if;

  raise notice 'Vytvořeno nových ukázkových tras: %.', v_created_count;
end
$$;

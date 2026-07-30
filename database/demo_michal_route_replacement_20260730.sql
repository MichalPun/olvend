-- Bezpečná náhrada rozpracované trasy 21 pro ukázku na poradě.
-- Původní dokončené návštěvy zůstávají zachované v historii.

do $$
declare
  v_route_id bigint;
  v_existing_id bigint;
begin
  update public.route_plan_stops
  set
    status = 'skipped',
    skipped_at = coalesce(skipped_at, now()),
    note = concat_ws(' · ', nullif(note, ''), 'Původní trasa nahrazena zkrácenou ukázkovou trasou.')
  where route_plan_id = 21
    and status = 'planned';

  update public.route_plans
  set
    execution_status = 'cancelled',
    title = 'PŮVODNÍ – NAHRAZENO UKÁZKOU · Michal Punčochář',
    updated_at = now()
  where id = 21
    and planned_employee_id = 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
    and execution_status in ('assigned', 'in_progress');

  select id into v_existing_id
  from public.route_plans
  where planning_date = '2026-07-30'::date
    and planned_employee_id = 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
    and route_payload ->> 'demo_key' = 'operator-meeting-20260730-michal'
  order by id desc
  limit 1;

  if v_existing_id is null then
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
      'UKÁZKA – PORADA · Michal Punčochář · káva + potraviny',
      1,
      'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid,
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
        'demo_key', 'operator-meeting-20260730-michal',
        'demo_notice', 'Ukázková trasa pro poradu. Jeden kávový a jeden potravinový automat.',
        'route_mode', 'training',
        'planned_employee_id', 'abad3293-29a0-4668-97c5-0c6fa08ece0f',
        'planned_employee_name', 'Michal Punčochář',
        'generated_at', now(),
        'replaces_route_id', 21
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
      d.stop_order,
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
        case when d.stop_order = 1 then 'kávový automat' else 'potravinový automat' end ||
        ' · EV ' || m.evidence_number
    from (values
      (1, 75::bigint),
      (2, 3::bigint)
    ) as d(stop_order, machine_id)
    join public.machines m on m.id = d.machine_id
    join public.locations l on l.id = m.location_id;
  else
    v_route_id := v_existing_id;

    update public.route_plans
    set
      execution_status = 'assigned',
      assigned_at = now(),
      started_at = null,
      completed_at = null,
      updated_at = now()
    where id = v_route_id;
  end if;

  if (
    select count(*)
    from public.route_plan_stops
    where route_plan_id = v_route_id
      and status = 'planned'
  ) <> 2 then
    raise exception 'Michalova ukázková trasa % nemá přesně dvě čekající zastávky.', v_route_id;
  end if;
end
$$;

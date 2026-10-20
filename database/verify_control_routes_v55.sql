begin;

select set_config(
  'request.jwt.claim.sub',
  (select auth_user_id::text from public.employees where active is true and auth_user_id is not null order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_employee uuid := public.current_employee_id();
  v_location bigint;
  v_machine bigint;
  v_route bigint;
  v_route_plan_count bigint;
  v_route_stop_count bigint;
begin
  select m.location_id, m.id into v_location, v_machine
  from public.machines m
  join public.locations l on l.id = m.location_id
  where m.active is true and l.active is true
  order by m.id
  limit 1;

  select count(*) into v_route_plan_count from public.route_plans;
  select count(*) into v_route_stop_count from public.route_plan_stops;

  v_route := public.create_control_route_v55(jsonb_build_object(
    'name', 'TEST control_routes_v55 rollback',
    'control_type', 'regular',
    'planned_date', current_date,
    'planned_start_time', '08:00',
    'assigned_employee_id', v_employee,
    'publish', true,
    'checklist_config', '{}'::jsonb,
    'rule_config', '{}'::jsonb,
    'stops', jsonb_build_array(jsonb_build_object(
      'location_id', v_location,
      'stop_order', 1,
      'machines', jsonb_build_array(jsonb_build_object('machine_id', v_machine))
    ))
  ));

  perform public.start_control_route_v55(v_route);

  if not exists (
    select 1 from public.control_routes
    where id = v_route and status = 'in_progress'
  ) then
    raise exception 'Kontrolni trasa nebyla vytvorena a zahajena.';
  end if;
  if (select count(*) from public.route_plans) <> v_route_plan_count then
    raise exception 'Kontrolni modul zmenil pocet beznych tras.';
  end if;
  if (select count(*) from public.route_plan_stops) <> v_route_stop_count then
    raise exception 'Kontrolni modul zmenil pocet zastavek beznych tras.';
  end if;
end;
$$;

rollback;

begin;

do $$
declare
  v_route public.route_plans%rowtype;
  v_last_stop_closed_at timestamptz;
  v_open_attendance boolean;
begin
  select *
    into v_route
  from public.route_plans
  where id = 49
  for update;

  if not found then
    raise exception 'Route 49 does not exist';
  end if;

  select max(coalesce(completed_at, skipped_at))
    into v_last_stop_closed_at
  from public.route_plan_stops
  where route_plan_id = v_route.id;

  select exists (
    select 1
    from public.attendance_days
    where employee_id = v_route.planned_employee_id
      and attendance_date = v_route.planning_date
      and actual_start is not null
      and actual_end is null
  ) into v_open_attendance;

  if v_route.planning_date <> date '2026-08-15'
     or v_route.return_to_start is not true
     or v_route.execution_status <> 'done'
     or v_route.completed_at is distinct from v_last_stop_closed_at
     or not v_open_attendance then
    raise exception 'Route 49 no longer matches the safe reopen conditions';
  end if;

  update public.route_plans
  set execution_status = 'in_progress',
      completed_at = null
  where id = v_route.id;
end
$$;

commit;

-- Uzavření výjezdu a výměna auta v otevřené směně. Celá operace je atomická.
begin;

create or replace function public.switch_shift_vehicle_v48(
  p_attendance_day_id bigint,
  p_previous_log_id bigint,
  p_vehicle_id bigint,
  p_end_odometer_km integer,
  p_start_odometer_km integer,
  p_route_plan_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_actor uuid;
  v_day public.attendance_days%rowtype;
  v_log public.vehicle_operation_logs%rowtype;
  v_vehicle public.vehicles%rowtype;
  v_plan public.route_plans%rowtype;
  v_end integer;
  v_new_log bigint;
  v_now timestamptz := now();
  v_note text;
begin
  select id into v_actor from public.employees
  where auth_user_id = auth.uid() and active is true
    and lower(role) in ('admin', 'manager');
  if v_actor is null then
    raise exception 'Výměnu auta může provést pouze vedení.';
  end if;

  select * into v_day from public.attendance_days
  where id = p_attendance_day_id for update;
  if not found or v_day.actual_start is null or v_day.actual_end is not null
    or v_day.status not in ('open', 'needs_review') then
    raise exception 'Směna není otevřená. Obnov přehled.';
  end if;
  if v_day.vehicle_id is null or p_vehicle_id is null or p_vehicle_id = v_day.vehicle_id then
    raise exception 'Vyber jiné vozidlo.';
  end if;

  -- Stejné pořadí zámků při současných výměnách dvou aut.
  perform id from public.vehicles
  where id in (v_day.vehicle_id, p_vehicle_id) order by id for update;
  select * into v_log from public.vehicle_operation_logs
  where id = p_previous_log_id for update;
  if not found or v_log.attendance_day_id is distinct from v_day.id
    or v_log.employee_id is distinct from v_day.employee_id
    or v_log.vehicle_id is distinct from v_day.vehicle_id
    or v_log.status <> 'open' or v_log.ended_at is not null
    or v_log.start_odometer_km is null then
    raise exception 'Výjezd se změnil nebo už byl uzavřen. Obnov přehled.';
  end if;
  if exists (select 1 from public.vehicle_operation_logs
    where attendance_day_id = v_day.id and id <> v_log.id
      and status = 'open' and ended_at is null and start_odometer_km is not null) then
    raise exception 'Směna má více otevřených výjezdů. Nejdřív oprav jejich evidenci.';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if not found or v_vehicle.active is not true then
    raise exception 'Nové vozidlo není aktivní.';
  end if;
  if exists (select 1 from public.attendance_days
    where vehicle_id = p_vehicle_id and id <> v_day.id
      and actual_start is not null and actual_end is null)
    or exists (select 1 from public.vehicle_operation_logs
    where vehicle_id = p_vehicle_id and status = 'open' and ended_at is null
      and start_odometer_km is not null) then
    raise exception 'Nové vozidlo má otevřený výjezd nebo směnu.';
  end if;
  if p_start_odometer_km is null or p_start_odometer_km < 0
    or p_start_odometer_km < coalesce(v_vehicle.current_odometer_km, 0) then
    raise exception 'Počáteční km nového auta jsou nižší než aktuální stav.';
  end if;

  if exists (select 1 from public.route_plans
    where planned_employee_id = v_day.employee_id and planning_date = v_day.attendance_date
      and execution_status = 'in_progress') then
    raise exception 'Nejdřív dokonči rozjetou trasu.';
  end if;
  v_end := p_end_odometer_km;
  if p_route_plan_id is not null then
    select * into v_plan from public.route_plans where id = p_route_plan_id for share;
    if not found or v_plan.planned_employee_id is distinct from v_day.employee_id
      or v_plan.vehicle_id is distinct from v_log.vehicle_id
      or v_plan.planning_date is distinct from v_day.attendance_date
      or v_plan.execution_status <> 'done'
      or v_plan.estimated_distance_km is null or v_plan.estimated_distance_km < 0 then
      raise exception 'Plán km nepatří k dokončené trase tohoto řidiče a auta.';
    end if;
    if exists (select 1 from public.vehicle_operation_logs
      where attendance_day_id = v_day.id and vehicle_id = v_log.vehicle_id
        and id <> v_log.id and start_odometer_km is not null)
      or (select count(*) from public.route_plans
        where planned_employee_id = v_day.employee_id and vehicle_id = v_log.vehicle_id
          and planning_date = v_day.attendance_date and execution_status = 'done') <> 1 then
      raise exception 'Pro více jízd zadej konečný tachometr ručně.';
    end if;
    v_end := v_log.start_odometer_km + round(v_plan.estimated_distance_km)::integer;
    if v_end is distinct from p_end_odometer_km then
      raise exception 'Plán km se změnil. Obnov přehled.';
    end if;
  end if;
  if v_end is null or v_end < v_log.start_odometer_km
    or v_end < (select coalesce(current_odometer_km, 0) from public.vehicles where id = v_log.vehicle_id)
    or (v_log.end_odometer_km is not null and v_log.end_odometer_km <> v_end) then
    raise exception 'Konečné km nesmějí snížit tachometr ani přepsat již uložený konec.';
  end if;
  v_note := format('Výměna vozidla %s → %s; konec %s km; nový start %s km; %s. %s',
    v_log.vehicle_id, p_vehicle_id, v_end, p_start_odometer_km,
    case when p_route_plan_id is null then 'ručně zadaný tachometr'
      else format('odhad podle plánu trasy #%s (%s km)', p_route_plan_id, v_plan.estimated_distance_km) end,
    coalesce(nullif(trim(p_note), ''), ''));
  update public.vehicle_operation_logs set ended_at = v_now,
    end_odometer_km = v_end, status = 'closed',
    trip_note = concat_ws(E'\n', nullif(trip_note, ''), v_note)
  where id = v_log.id;
  update public.vehicles set current_odometer_km = v_end where id = v_log.vehicle_id;
  update public.vehicles set current_odometer_km = p_start_odometer_km where id = p_vehicle_id;
  insert into public.vehicle_operation_logs
    (vehicle_id, employee_id, attendance_day_id, log_date, started_at, start_odometer_km, status, trip_note)
  values (p_vehicle_id, v_day.employee_id, v_day.id, v_day.attendance_date, v_now,
    p_start_odometer_km, 'open', v_note)
  returning id into v_new_log;
  update public.attendance_days set vehicle_id = p_vehicle_id where id = v_day.id;
  insert into public.attendance_events
    (attendance_day_id, employee_id, event_type, event_time, note, created_by)
  values (v_day.id, v_day.employee_id, 'manual_adjustment', v_now, v_note, v_actor);
  return jsonb_build_object('previous_log_id', v_log.id, 'new_log_id', v_new_log,
    'vehicle_id', p_vehicle_id, 'end_odometer_km', v_end, 'start_odometer_km', p_start_odometer_km);
end;
$$;

revoke all on function public.switch_shift_vehicle_v48(bigint,bigint,bigint,integer,integer,bigint,text) from public, anon;
grant execute on function public.switch_shift_vehicle_v48(bigint,bigint,bigint,integer,integer,bigint,text) to authenticated;
commit;

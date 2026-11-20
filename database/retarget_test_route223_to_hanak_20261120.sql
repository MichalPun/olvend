-- Zpřístupní dnešní nedotčenou testovací trasu Michalovi a přesměruje ji
-- na dvojici aktivních automatů, které 20. 11. 2026 nejsou v žádné jiné trase.
-- Reálné trasy ani návštěvy jiných operátorů se nemění.

begin;

do $$
declare
  v_route public.route_plans%rowtype;
  v_location public.locations%rowtype;
  v_michal constant uuid := 'abad3293-29a0-4668-97c5-0c6fa08ece0f';
  v_vehicle constant bigint := 6;
  v_coffee_machine constant bigint := 22; -- EV 27
  v_food_machine constant bigint := 19;   -- EV 23
begin
  perform pg_advisory_xact_lock(hashtextextended('retarget-test-route-223-20261120', 0));

  select * into v_route
  from public.route_plans
  where id = 223
  for update;

  if not found then
    raise exception 'Zkušební trasa 223 nebyla nalezena.';
  end if;

  if v_route.planning_date <> date '2026-11-19'
     or v_route.planned_employee_id <> v_michal
     or v_route.vehicle_id <> v_vehicle
     or v_route.execution_status <> 'assigned'
     or v_route.started_at is not null
     or v_route.completed_at is not null
     or coalesce((v_route.route_payload ->> 'test_mode')::boolean, false) is not true
     or coalesce((v_route.route_payload ->> 'isolated_stock')::boolean, false) is not true
     or coalesce(v_route.route_payload ->> 'test_key', '') <> 'operator-full-sportisimo-v2'
     or coalesce((v_route.route_payload ->> 'temporary')::boolean, false) is not true then
    raise exception 'Trasa 223 už není nedotčená včerejší testovací trasa; změna zastavena.';
  end if;

  if (select count(*) from public.route_plan_stops stop where stop.route_plan_id = v_route.id) <> 2
     or exists (
       select 1 from public.route_plan_stops stop
       where stop.route_plan_id = v_route.id
         and (stop.status <> 'planned'
           or stop.arrived_at is not null
           or stop.completed_at is not null
           or stop.skipped_at is not null)
     )
     or exists (select 1 from public.route_machine_visits visit where visit.route_plan_id = v_route.id) then
    raise exception 'Zkušební trasa už obsahuje práci; změna zastavena.';
  end if;

  if not exists (
    select 1 from public.attendance_days attendance
    where attendance.employee_id = v_michal
      and attendance.attendance_date = date '2026-11-20'
      and attendance.status = 'open'
      and attendance.actual_start is not null
      and attendance.actual_end is null
      and attendance.vehicle_id = v_vehicle
  ) then
    raise exception 'Dnešní otevřená směna Michala s vozidlem 6 nebyla nalezena.';
  end if;

  if exists (
    select 1 from public.route_plans route
    where route.id <> v_route.id
      and route.planning_date = date '2026-11-20'
      and route.planned_employee_id = v_michal
      and route.execution_status <> 'cancelled'
  ) then
    raise exception 'Michal už má na dnešek jinou trasu.';
  end if;

  select * into strict v_location
  from public.locations
  where id = 111;

  if (select count(*) from public.machines machine
      where machine.id in (v_coffee_machine, v_food_machine)
        and machine.location_id = v_location.id
        and machine.active is true
        and machine.status is distinct from 'removed') <> 2 then
    raise exception 'Vybrané automaty EV 27 a EV 23 nejsou oba aktivní na lokalitě Hanák.';
  end if;

  if exists (
    select 1
    from public.route_plan_stops stop
    join public.route_plans route on route.id = stop.route_plan_id
    where route.id <> v_route.id
      and route.planning_date = date '2026-11-20'
      and route.execution_status <> 'cancelled'
      and stop.machine_id in (v_coffee_machine, v_food_machine)
  ) then
    raise exception 'EV 27 nebo EV 23 se mezitím objevilo v jiné dnešní trase.';
  end if;

  if exists (
    select 1 from public.route_machine_visits visit
    where visit.machine_id in (v_coffee_machine, v_food_machine)
      and visit.status not in ('done', 'completed', 'skipped', 'cancelled')
  ) then
    raise exception 'EV 27 nebo EV 23 má otevřenou návštěvu.';
  end if;

  update public.route_plans
  set planning_date = date '2026-11-20',
      title = '[TEST] Blučina → HANÁK NÁBYTEK · EV 27 + EV 23',
      planned_departure_time = localtime,
      execution_status = 'assigned',
      assigned_at = now(),
      started_at = null,
      completed_at = null,
      end_latitude = v_location.latitude,
      end_longitude = v_location.longitude,
      estimated_distance_km = 79,
      estimated_drive_minutes = 70,
      estimated_service_minutes = 55,
      route_payload = route_payload || jsonb_build_object(
        'moved_to_date', '2026-11-20',
        'moved_for_login_test', true,
        'retargeted_from_machine_ids', jsonb_build_array(65, 70),
        'test_location_id', v_location.id,
        'test_machine_ids', jsonb_build_array(v_coffee_machine, v_food_machine),
        'instructions', 'Plnohodnotný test na EV 27 a EV 23, které dnes nejsou v jiné trase. Po testu se trasa smaže.'
      ),
      updated_at = now()
  where id = v_route.id;

  update public.route_plan_stops
  set location_id = v_location.id,
      machine_id = v_coffee_machine,
      title = 'HANÁK NÁBYTEK · EV 27 · Luce X2 I/E kuchyňka',
      address_snapshot = v_location.address,
      city_snapshot = v_location.city,
      latitude = v_location.latitude,
      longitude = v_location.longitude,
      estimated_service_minutes = 25,
      note = 'První automat na lokalitě · kávový · dnešní test bez kolize.',
      status = 'planned',
      arrived_at = null,
      completed_at = null,
      skipped_at = null
  where route_plan_id = v_route.id
    and stop_order = 1;

  update public.route_plan_stops
  set location_id = v_location.id,
      machine_id = v_food_machine,
      title = 'HANÁK NÁBYTEK · EV 23 · Luce Snack X',
      address_snapshot = v_location.address,
      city_snapshot = v_location.city,
      latitude = v_location.latitude,
      longitude = v_location.longitude,
      estimated_service_minutes = 30,
      note = 'Druhý automat na lokalitě · potravinový · dnešní test bez kolize.',
      status = 'planned',
      arrived_at = null,
      completed_at = null,
      skipped_at = null
  where route_plan_id = v_route.id
    and stop_order = 2;

  if (select count(*) from public.route_plan_stops stop
      where stop.route_plan_id = v_route.id
        and stop.machine_id in (v_coffee_machine, v_food_machine)
        and stop.location_id = v_location.id
        and stop.status = 'planned') <> 2 then
    raise exception 'Kontrola nových zastávek selhala.';
  end if;
end
$$;

commit;

select jsonb_build_object(
  'route_id', route.id,
  'date', route.planning_date,
  'title', route.title,
  'status', route.execution_status,
  'employee_id', route.planned_employee_id,
  'vehicle_id', route.vehicle_id,
  'vehicle_plate', vehicle.plate,
  'attendance_open', exists (
    select 1 from public.attendance_days attendance
    where attendance.employee_id = route.planned_employee_id
      and attendance.attendance_date = route.planning_date
      and attendance.status = 'open'
      and attendance.actual_end is null
  ),
  'stops', (
    select jsonb_agg(jsonb_build_object(
      'order', stop.stop_order,
      'machine_id', stop.machine_id,
      'ev', machine.evidence_number,
      'type', machine.machine_type,
      'status', stop.status
    ) order by stop.stop_order)
    from public.route_plan_stops stop
    join public.machines machine on machine.id = stop.machine_id
    where stop.route_plan_id = route.id
  ),
  'visits', (
    select count(*) from public.route_machine_visits visit where visit.route_plan_id = route.id
  )
) as result
from public.route_plans route
join public.vehicles vehicle on vehicle.id = route.vehicle_id
where route.id = 223;

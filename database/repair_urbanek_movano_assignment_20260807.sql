-- Lukáš Urbánek měl 7. 8. 2026 Movano přiřazené v trase 39 i v návštěvě,
-- ale chybělo ve směně a nevznikl jízdní záznam. To blokovalo dokončení.

do $$
declare
  v_employee_id constant uuid := 'ba6be55d-1b4c-4c59-a995-274157d61306';
  v_attendance_day_id constant bigint := 368;
  v_vehicle_id constant bigint := 4;
  v_route_id constant bigint := 39;
  v_start timestamptz;
  v_start_km integer;
begin
  select ad.actual_start
    into strict v_start
  from public.attendance_days ad
  where ad.id = v_attendance_day_id
    and ad.employee_id = v_employee_id
    and ad.attendance_date = date '2026-08-07'
    and ad.actual_end is null;

  if not exists (
    select 1 from public.route_plans rp
    where rp.id = v_route_id
      and rp.planned_employee_id = v_employee_id
      and rp.vehicle_id = v_vehicle_id
      and rp.execution_status = 'in_progress'
  ) then
    raise exception 'Dnešní rozpracovaná trasa Lukáše Urbánka nemá očekávané Movano.';
  end if;

  if exists (
    select 1 from public.vehicle_operation_logs vol
    where vol.vehicle_id = v_vehicle_id
      and vol.log_date = date '2026-08-07'
      and vol.employee_id is distinct from v_employee_id
      and vol.status in ('draft', 'open')
  ) then
    raise exception 'Movano už má dnes otevřenou jízdu jiného zaměstnance.';
  end if;

  select current_odometer_km
    into strict v_start_km
  from public.vehicles
  where id = v_vehicle_id and active;

  update public.attendance_days
  set vehicle_id = v_vehicle_id,
      note = concat_ws(' · ', nullif(note, ''), 'Movano doplněno administrativně 7. 8. 2026 podle přiřazení trasy 39.')
  where id = v_attendance_day_id
    and vehicle_id is null;

  if not exists (
    select 1 from public.vehicle_operation_logs vol
    where vol.attendance_day_id = v_attendance_day_id
  ) then
    insert into public.vehicle_operation_logs (
      vehicle_id,
      employee_id,
      attendance_day_id,
      log_date,
      started_at,
      start_odometer_km,
      status,
      trip_note
    ) values (
      v_vehicle_id,
      v_employee_id,
      v_attendance_day_id,
      date '2026-08-07',
      v_start,
      v_start_km,
      'open',
      'Jízdní záznam doplněn administrativně podle trasy 39; při zahájení směny se vozidlo nepropsalo.'
    );
  end if;

  update public.route_machine_visits
  set vehicle_id = v_vehicle_id,
      synced_at = now()
  where route_plan_id = v_route_id
    and vehicle_id is null;
end
$$;

select
  ad.id as attendance_day_id,
  ad.vehicle_id,
  v.name as vehicle_name,
  v.plate,
  vol.id as vehicle_log_id,
  vol.status as vehicle_log_status,
  vol.start_odometer_km
from public.attendance_days ad
join public.vehicles v on v.id = ad.vehicle_id
left join public.vehicle_operation_logs vol on vol.attendance_day_id = ad.id
where ad.id = 368;

begin;

do $$
declare
  belgian_id bigint;
  meatball_id bigint;
  teriyaki_id bigint;
begin
  select id into belgian_id
  from public.products
  where sku = '79' and name = 'ATM - Belgická bageta';

  select id into meatball_id
  from public.products
  where sku = '278' and name = 'ATM - Bageta s mas. koul.';

  select id into teriyaki_id
  from public.products
  where sku = '282' and name = 'ATM - Kuře teriyaki';

  if belgian_id is null or meatball_id is null or teriyaki_id is null then
    raise exception 'Expected ATM products SKU 79, 278 and 282 were not found.';
  end if;

  if not exists (
    select 1
    from public.machine_planogram_slots
    where active is true and product_sku in ('79', '278')
  ) then
    raise exception 'No active Belgian or meatball-bagette slots were found.';
  end if;

  -- The product changes physically only when the operator confirms the slot
  -- at the next machine visit.
  update public.machine_planogram_slots
  set pending_product_id = teriyaki_id,
      pending_product_sku = '282',
      pending_product_name = 'ATM - Kuře teriyaki',
      pending_change_effective_date = current_date,
      pending_change_note = 'Hromadná změna 31. 7. 2026: Belgická -> Kuře teriyaki',
      updated_at = now()
  where active is true
    and product_sku = '79';

  update public.machine_planogram_slots
  set pending_product_id = belgian_id,
      pending_product_sku = '79',
      pending_product_name = 'ATM - Belgická bageta',
      pending_change_effective_date = current_date,
      pending_change_note = 'Hromadná změna 31. 7. 2026: Masové koule -> Belgická',
      updated_at = now()
  where active is true
    and product_sku = '278';

  -- Keep the discontinued product readable on slots until their physical
  -- exchange, but remove it from the list of allowed new substitutions.
  update public.products
  set active = false
  where id = meatball_id;
end
$$;

do $$
declare
  vivaro_id bigint;
begin
  select id into vivaro_id
  from public.vehicles
  where plate = '3BJ1780' and name = 'Opel Vivaro';

  if vivaro_id is null then
    raise exception 'Opel Vivaro 3BJ1780 was not found.';
  end if;

  if not exists (
    select 1
    from public.vehicle_operation_logs
    where vehicle_id = vivaro_id
      and log_date = date '2026-07-13'
      and start_odometer_km = 138949
      and end_odometer_km = 739403
  ) then
    raise exception 'The first propagated 600000 km Vivaro error was not found.';
  end if;

  -- The extra 600,000 km first appeared at the end of 13 July and was then
  -- copied into subsequent starts and ends.
  update public.vehicle_operation_logs
  set start_odometer_km = case
        when start_odometer_km >= 700000 then start_odometer_km - 600000
        else start_odometer_km
      end,
      end_odometer_km = case
        when end_odometer_km >= 700000 then end_odometer_km - 600000
        else end_odometer_km
      end
  where vehicle_id = vivaro_id
    and (
      coalesce(start_odometer_km, 0) >= 700000
      or coalesce(end_odometer_km, 0) >= 700000
    );

  -- Shift-start notes are historical display text; align them with corrected
  -- operation logs so the bad value does not remain visible elsewhere.
  update public.attendance_events ae
  set note = 'Vozidlo 3BJ1780, km ' || vol.start_odometer_km
  from public.vehicle_operation_logs vol
  where vol.vehicle_id = vivaro_id
    and vol.attendance_day_id = ae.attendance_day_id
    and ae.event_type = 'shift_start'
    and ae.note like 'Vozidlo 3BJ1780, km 7%';

  -- User-confirmed real current state.
  update public.vehicles
  set current_odometer_km = 143566
  where id = vivaro_id;
end
$$;

commit;

select
  product_sku,
  pending_product_sku,
  count(*) as slot_count
from public.machine_planogram_slots
where active is true
  and product_sku in ('79', '278')
group by product_sku, pending_product_sku
order by product_sku;

select id, sku, name, active
from public.products
where sku in ('79', '278', '282')
order by sku;

select
  v.id,
  v.name,
  v.plate,
  v.current_odometer_km,
  count(*) filter (
    where coalesce(vol.start_odometer_km, 0) >= 700000
       or coalesce(vol.end_odometer_km, 0) >= 700000
  ) as remaining_bad_logs,
  max(vol.distance_km) as largest_recorded_trip_km
from public.vehicles v
left join public.vehicle_operation_logs vol on vol.vehicle_id = v.id
where v.plate = '3BJ1780'
group by v.id, v.name, v.plate, v.current_odometer_km;

begin;

do $$
declare
  v_vehicle_id bigint;
  v_vehicle_note text := 'VIN ZFA26300009224979 · první registrace 19. 2. 2013 · registrace v ČR 6. 10. 2026 · kategorie N1 · 1 598 cm3 · 77 kW · EURO 5 · kombinovaná spotřeba 5,5 l/100 km · osvědčení UBP212114';
begin
  insert into public.vehicles (
    name,
    plate,
    brand,
    model,
    fuel_type,
    target_consumption_l_100km,
    service_scope,
    note,
    active
  )
  values (
    'Fiat Doblò Cargo',
    '3BU9736',
    'Fiat',
    'Doblò Cargo 1.6 JTD',
    'diesel',
    5.5,
    'mixed',
    v_vehicle_note,
    true
  )
  on conflict (plate) do update
  set
    name = excluded.name,
    brand = excluded.brand,
    model = excluded.model,
    fuel_type = excluded.fuel_type,
    target_consumption_l_100km = excluded.target_consumption_l_100km,
    service_scope = excluded.service_scope,
    note = case
      when coalesce(public.vehicles.note, '') ilike '%ZFA26300009224979%' then public.vehicles.note
      else concat_ws(' · ', nullif(public.vehicles.note, ''), excluded.note)
    end,
    active = true
  returning id into v_vehicle_id;

  if not exists (
    select 1
    from public.stock_locations
    where location_type = 'vehicle'
      and vehicle_id = v_vehicle_id
      and active is true
  ) then
    insert into public.stock_locations (
      location_type,
      name,
      vehicle_id,
      active,
      note
    )
    values (
      'vehicle',
      'Fiat Doblò Cargo · 3BU9736',
      v_vehicle_id,
      true,
      'Sklad vozidla založený při zařazení do vozového parku 9. 10. 2026.'
    );
  end if;
end;
$$;

commit;

select
  v.id,
  v.name,
  v.plate,
  v.brand,
  v.model,
  v.fuel_type,
  v.target_consumption_l_100km,
  v.warehouse_id,
  v.assigned_employee_id,
  v.current_odometer_km,
  v.active,
  sl.id as stock_location_id,
  sl.name as stock_location_name
from public.vehicles v
left join public.stock_locations sl
  on sl.vehicle_id = v.id
 and sl.location_type = 'vehicle'
 and sl.active is true
where v.plate = '3BU9736';

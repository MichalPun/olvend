-- Oprava dvou kávových návštěv z trasy 37 dne 7. 8. 2026.
-- Microtechnic EV 37 a ViaPharma EV 22 neměly aktivní kávový plánogram,
-- takže mobil zůstal v prázdném picklistu a návštěvy nešlo uzavřít.
-- Ve ViaPharmě operátorka skutečně doplnila 4 tyče kelímků 180 ml po 50 ks.

do $$
declare
  v_route_id constant bigint := 37;
  v_microtechnic_stop_id constant bigint := 306;
  v_microtechnic_visit_id constant bigint := 146;
  v_viapharma_stop_id constant bigint := 310;
  v_viapharma_visit_id constant bigint := 150;
  v_viapharma_machine_id constant bigint := 18;
  v_cup_product_id constant bigint := 78;
  v_cup_package_id constant bigint := 24;
  v_vehicle_id bigint;
  v_vehicle_stock_location_id bigint;
  v_machine_stock_location_id bigint;
  v_employee_id uuid;
  v_now timestamptz := now();
  v_note text := 'Administrativně uzavřeno 7. 8. 2026: mobilní aplikace zablokovala návštěvu kvůli chybějícímu aktivnímu kávovému plánogramu. Kontroly a hotovost nebyly v mobilu zachyceny.';
begin
  select rp.vehicle_id, rp.planned_employee_id
    into strict v_vehicle_id, v_employee_id
  from public.route_plans rp
  where rp.id = v_route_id
    and rp.planning_date = date '2026-08-07';

  if v_vehicle_id <> 2 then
    raise exception 'Trasa 37 nemá očekávané vozidlo Opel Vivaro (id 2), ale %.', v_vehicle_id;
  end if;

  select sl.id
    into strict v_vehicle_stock_location_id
  from public.stock_locations sl
  where sl.location_type = 'vehicle'
    and sl.vehicle_id = v_vehicle_id
    and sl.active
  order by sl.id
  limit 1;

  select sl.id
    into v_machine_stock_location_id
  from public.stock_locations sl
  where sl.location_type = 'machine'
    and sl.machine_id = v_viapharma_machine_id
    and sl.active
  order by sl.id
  limit 1;

  if v_machine_stock_location_id is null then
    insert into public.stock_locations (location_type, name, machine_id, active, note)
    values (
      'machine',
      'ViaPharma · EV 22',
      v_viapharma_machine_id,
      true,
      'Vytvořeno při opravě návštěvy trasy 37 dne 7. 8. 2026.'
    )
    returning id into v_machine_stock_location_id;
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13 sm
    where sm.reference_type = 'mobile_stock_request'
      and sm.reference_id = 'route_visit_150_cups_180ml_manual_4packs'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_cup_product_id,
          'batch_id', null,
          'from_stock_location_id', v_vehicle_stock_location_id,
          'to_stock_location_id', v_machine_stock_location_id,
          'movement_type', 'fill_machine',
          'quantity_base_units', 200,
          'reference_type', 'mobile_stock_request',
          'reference_id', 'route_visit_150_cups_180ml_manual_4packs',
          'note', 'Trasa 37 · Michaela Nerudová · ViaPharma EV 22 · doplněny 4 tyče kelímků 180 ml po 50 ks'
        )
      )
    );

    update public.stock_movements_v13
    set package_id = v_cup_package_id,
        package_count = 4,
        created_by = v_employee_id
    where reference_type = 'mobile_stock_request'
      and reference_id = 'route_visit_150_cups_180ml_manual_4packs';
  end if;

  if not exists (
    select 1
    from public.route_machine_visit_items i
    where i.visit_id = v_viapharma_visit_id
      and i.item_kind = 'service_item'
      and i.actual_product_id = v_cup_product_id
      and i.operator_note ilike '%4 tyče%'
  ) then
    insert into public.route_machine_visit_items (
      visit_id,
      machine_id,
      item_kind,
      physical_position_label,
      planned_product_id,
      planned_product_sku,
      planned_product_name,
      actual_product_id,
      actual_product_sku,
      actual_product_name,
      suggested_add_quantity,
      actual_add_quantity,
      final_quantity,
      unit,
      operator_note,
      accepted_at
    ) values (
      v_viapharma_visit_id,
      v_viapharma_machine_id,
      'service_item',
      'Zásobník kelímků',
      v_cup_product_id,
      '45',
      'Kelímek 180 ml',
      v_cup_product_id,
      '45',
      'Kelímek 180 ml',
      200,
      200,
      200,
      'ks',
      'Dodatečně zapsáno dle hlášení operátorky: doplněny 4 tyče po 50 ks; odečteno z Opel Vivaro 3BJ1780.',
      v_now
    );
  end if;

  update public.route_machine_visits
  set status = 'completed',
      work_phase = 'machine',
      completed_at = coalesce(completed_at, v_now),
      operator_note = concat_ws(' · ', nullif(operator_note, ''), v_note),
      synced_at = v_now
  where id in (v_microtechnic_visit_id, v_viapharma_visit_id)
    and route_plan_id = v_route_id
    and status <> 'completed';

  update public.route_plan_stops
  set status = 'done',
      completed_at = coalesce(completed_at, v_now)
  where id in (v_microtechnic_stop_id, v_viapharma_stop_id)
    and route_plan_id = v_route_id
    and status <> 'done';
end
$$;

select
  rp.id as route_id,
  rp.execution_status,
  s.id as stop_id,
  l.name as location_name,
  s.status as stop_status,
  v.id as visit_id,
  v.status as visit_status,
  v.completed_at,
  coalesce((select sum(i.actual_add_quantity) from public.route_machine_visit_items i where i.visit_id = v.id and i.actual_product_id = 78), 0) as cups_180_added,
  (select sum(b.quantity_on_hand) from public.stock_location_balances b where b.stock_location_id = 3 and b.product_id = 78) as vivaro_cups_180_remaining
from public.route_plans rp
join public.route_plan_stops s on s.route_plan_id = rp.id
left join public.locations l on l.id = s.location_id
left join public.route_machine_visits v on v.route_plan_stop_id = s.id
where rp.id = 37
  and s.id in (306, 310)
order by s.stop_order;

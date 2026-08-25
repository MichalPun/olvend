-- Doplneni chybejiciho auditu dnesni navstevy Kristyny Dvorakove v Lasspektru.
-- Trasa #70, zastavka #707, navsteva #415, EV 17 / Luce X2 I.
-- Fyzicky doplneno: 3 tyce Kelimek 180 ml = 150 ks a 1 kg kakaove smesi.

begin;

do $$
declare
  v_visit_id constant bigint := 415;
  v_route_id constant bigint := 70;
  v_stop_id constant bigint := 707;
  v_machine_id constant bigint := 14;
  v_vehicle_id constant bigint := 3;
  v_vehicle_location_id constant bigint := 4;
  v_machine_location_id constant bigint := 19;
  v_accepted_at constant timestamptz := timestamp with time zone '2026-08-25 05:16:49+00';
begin
  if not exists (
    select 1
    from public.route_machine_visits visit
    where visit.id = v_visit_id
      and visit.route_plan_id = v_route_id
      and visit.route_plan_stop_id = v_stop_id
      and visit.machine_id = v_machine_id
      and visit.vehicle_id = v_vehicle_id
      and visit.visit_date = date '2026-08-25'
      and visit.status = 'completed'
  ) then
    raise exception 'Navsteva #415 neodpovida dnesni dokoncene zastavce Kristyny v Lasspektru.';
  end if;

  if not exists (
    select 1 from public.stock_locations
    where id = v_vehicle_location_id and location_type = 'vehicle' and vehicle_id = v_vehicle_id
  ) or not exists (
    select 1 from public.stock_locations
    where id = v_machine_location_id and location_type = 'machine' and machine_id = v_machine_id
  ) then
    raise exception 'Skladova mista Fiatu Doblo nebo EV 17 neodpovidaji auditu.';
  end if;

  if not exists (
    select 1 from public.machine_coffee_containers
    where id = 359 and machine_id = v_machine_id and product_id = 78
      and container_code = 'Z7' and unit = 'ks' and capacity_quantity = 400 and active
  ) or not exists (
    select 1 from public.machine_coffee_containers
    where id = 356 and machine_id = v_machine_id and product_id = 106
      and container_code = 'Z4' and unit = 'g' and capacity_quantity = 2000 and active
  ) then
    raise exception 'Planogram EV 17 se zmenil; oprava nebyla provedena.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = 'manager-correction-route70-stop707-visit415-20260825'
  ) then
    perform public.apply_stock_movements_v13(jsonb_build_array(
      jsonb_build_object(
        'product_id', 106,
        'batch_id', null,
        'from_stock_location_id', null,
        'to_stock_location_id', v_vehicle_location_id,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'mobile_stock_request',
        'reference_id', 'manager-correction-route70-stop707-visit415-20260825',
        'note', 'Lasspektrum EV 17 · navsteva #415 · dorovnani fyzicky nalezeneho 1kg baleni kakaove smesi, ktere evidence Fiatu pred navstevou nevedla'
      ),
      jsonb_build_object(
        'product_id', 78,
        'batch_id', null,
        'from_stock_location_id', v_vehicle_location_id,
        'to_stock_location_id', v_machine_location_id,
        'movement_type', 'fill_machine',
        'quantity_base_units', 150,
        'reference_type', 'mobile_stock_request',
        'reference_id', 'manager-correction-route70-stop707-visit415-20260825',
        'note', 'Kristyna Dvorakova · trasa #70 · Lasspektrum EV 17 · navsteva #415 · doplneny 3 tyce Kelimek 180 ml, 1 tyc = 50 ks'
      ),
      jsonb_build_object(
        'product_id', 106,
        'batch_id', null,
        'from_stock_location_id', v_vehicle_location_id,
        'to_stock_location_id', v_machine_location_id,
        'movement_type', 'fill_machine',
        'quantity_base_units', 1,
        'reference_type', 'mobile_stock_request',
        'reference_id', 'manager-correction-route70-stop707-visit415-20260825',
        'note', 'Kristyna Dvorakova · trasa #70 · Lasspektrum EV 17 · navsteva #415 · doplneno 1kg baleni oVe DRINK WITH COCOA'
      )
    ));
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items
    where client_uuid = '41500000-0000-4000-8000-000000000078'::uuid
  ) then
    insert into public.route_machine_visit_items (
      visit_id, client_uuid, machine_id, item_kind, coffee_container_id,
      physical_position_label,
      planned_product_id, planned_product_sku, planned_product_name,
      actual_product_id, actual_product_sku, actual_product_name,
      system_current_quantity, actual_before_quantity,
      suggested_add_quantity, actual_add_quantity, removed_quantity,
      final_quantity, capacity_quantity, unit,
      issue_type, operator_note, accepted_at
    ) values (
      v_visit_id, '41500000-0000-4000-8000-000000000078', v_machine_id, 'coffee_container', 359,
      'Z7',
      78, '45', 'Kelimek 180 ml',
      78, '45', 'Kelimek 180 ml',
      363, 213,
      0, 150, 0,
      363, 400, 'ks',
      'telemetry_mismatch',
      'Manazerska oprava 25. 8. 2026: Kristyna fyzicky doplnila 3 tyce Kelimek 180 ml = 150 ks. Pick-list navrhl 0 a mobilni proces krok doplneni preskocil.',
      v_accepted_at
    );
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items
    where client_uuid = '41500000-0000-4000-8000-000000000106'::uuid
  ) then
    insert into public.route_machine_visit_items (
      visit_id, client_uuid, machine_id, item_kind, coffee_container_id,
      physical_position_label,
      planned_product_id, planned_product_sku, planned_product_name,
      actual_product_id, actual_product_sku, actual_product_name,
      system_current_quantity, actual_before_quantity,
      suggested_add_quantity, actual_add_quantity, removed_quantity,
      final_quantity, capacity_quantity, unit,
      issue_type, operator_note, accepted_at
    ) values (
      v_visit_id, '41500000-0000-4000-8000-000000000106', v_machine_id, 'coffee_container', 356,
      'Z4',
      106, '47', 'oVe DRINK WITH COCOA 1 kg',
      106, '47', 'oVe DRINK WITH COCOA 1 kg',
      1270, 270,
      0, 1000, 0,
      1270, 2000, 'g',
      'telemetry_mismatch',
      'Manazerska oprava 25. 8. 2026: Kristyna fyzicky doplnila 1kg baleni kakaove smesi. Evidence Fiatu pred navstevou vedla 0 kg a mobilni proces krok doplneni preskocil.',
      v_accepted_at
    );
  end if;
end
$$;

commit;

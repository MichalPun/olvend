-- Recreate route 39 after duplicated mobile coffee-container confirmations.
-- The operator physically filled 2 kg Irish Cream and 0.5 kg Sophia, but will
-- record the visit again on a clean route. Return those quantities to Movano
-- and restore the container snapshot before creating the replacement route.

do $$
declare
  v_old_route public.route_plans%rowtype;
  v_old_stop public.route_plan_stops%rowtype;
  v_new_route_id bigint;
  v_reset_key constant text := 'urbanek-route39-mobile-sync-reset-20260807';
begin
  select * into v_old_route
  from public.route_plans
  where id = 39
  for update;

  if not found
     or v_old_route.planned_employee_id <> 'ba6be55d-1b4c-4c59-a995-274157d61306'::uuid
     or v_old_route.vehicle_id <> 4 then
    raise exception 'Route 39 no longer matches Lukas Urbanek and Opel Movano.';
  end if;

  select id into v_new_route_id
  from public.route_plans
  where route_payload ->> 'reset_key' = v_reset_key
  order by id desc
  limit 1;

  if v_new_route_id is not null then
    return;
  end if;

  select * into v_old_stop
  from public.route_plan_stops
  where route_plan_id = 39 and id = 342
  for update;

  if not found then
    raise exception 'Original route stop 342 is missing.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where id = 28324 and product_id = 110
      and from_stock_location_id = 58 and to_stock_location_id = 35
      and quantity_base_units = 1
  ) or not exists (
    select 1 from public.stock_movements_v13
    where id = 28325 and product_id = 108
      and from_stock_location_id = 58 and to_stock_location_id = 35
      and quantity_base_units = 0.5
  ) or not exists (
    select 1 from public.stock_movements_v13
    where id = 28381 and product_id = 110
      and from_stock_location_id = 58 and to_stock_location_id = 35
      and quantity_base_units = 1
  ) then
    raise exception 'Expected route 39 stock movements do not match the audit.';
  end if;

  perform public.apply_stock_movements_v13(
    jsonb_build_array(
      jsonb_build_object(
        'product_id', 110,
        'batch_id', null,
        'from_stock_location_id', 35,
        'to_stock_location_id', 58,
        'movement_type', 'return',
        'quantity_base_units', 2,
        'package_count', 2,
        'reference_type', 'route_reset',
        'reference_id', v_reset_key || '-irish-cream',
        'note', 'Reset trasy 39: vraceni 2 kg Irish Cream z automatu zpet na Opel Movano pred novym zapisem navstevy.'
      ),
      jsonb_build_object(
        'product_id', 108,
        'batch_id', null,
        'from_stock_location_id', 35,
        'to_stock_location_id', 58,
        'movement_type', 'return',
        'quantity_base_units', 0.5,
        'package_count', 1,
        'reference_type', 'route_reset',
        'reference_id', v_reset_key || '-sophia',
        'note', 'Reset trasy 39: vraceni 0,5 kg Sophia z automatu zpet na Opel Movano pred novym zapisem navstevy.'
      )
    )
  );

  update public.machine_coffee_containers
  set current_quantity = case id
        when 161 then 662
        when 162 then 1468.2
      end,
      updated_at = now()
  where id in (161, 162) and machine_id = 25;

  update public.route_machine_visit_items
  set operator_note = concat_ws(
        ' · ',
        nullif(operator_note, ''),
        'Stornováno při technickém resetu trasy; zásoba vrácena na Movano.'
      )
  where visit_id = 172;

  update public.route_machine_visits
  set status = 'skipped',
      skipped_at = now(),
      skip_reason = 'route_recreated_after_mobile_sync_issue',
      operator_note = concat_ws(' · ', nullif(operator_note, ''), 'Návštěva stornována; nahrazena novou trasou.'),
      updated_at = now()
  where id = 172 and route_plan_id = 39;

  update public.route_plan_stops
  set status = 'skipped',
      skipped_at = now(),
      note = concat_ws(' · ', nullif(note, ''), 'Stornováno kvůli chybnému potvrzování zásobníků v mobilu; vytvořena nová kopie.')
  where id = 342 and route_plan_id = 39;

  update public.route_plans
  set execution_status = 'cancelled',
      title = 'ZRUŠENO – TECHNICKÝ RESET · ' || title,
      completed_at = now(),
      updated_at = now()
  where id = 39;

  insert into public.route_plans (
    planning_date, title, vehicle_id, planned_employee_id, warehouse_id,
    planner_mode, optimization_provider, provider_status,
    start_latitude, start_longitude, end_latitude, end_longitude,
    return_to_start, stop_count, estimated_distance_km,
    estimated_drive_minutes, estimated_service_minutes, route_payload,
    created_by, execution_status, assigned_at, started_at, completed_at,
    route_template_id, planned_departure_time
  )
  values (
    v_old_route.planning_date, v_old_route.title, v_old_route.vehicle_id,
    v_old_route.planned_employee_id, v_old_route.warehouse_id,
    v_old_route.planner_mode, v_old_route.optimization_provider, v_old_route.provider_status,
    v_old_route.start_latitude, v_old_route.start_longitude,
    v_old_route.end_latitude, v_old_route.end_longitude,
    v_old_route.return_to_start, v_old_route.stop_count,
    v_old_route.estimated_distance_km, v_old_route.estimated_drive_minutes,
    v_old_route.estimated_service_minutes,
    v_old_route.route_payload || jsonb_build_object(
      'generated_at', now(),
      'replaces_route_id', 39,
      'reset_key', v_reset_key,
      'reset_reason', 'mobile_coffee_container_confirmation_issue'
    ),
    v_old_route.created_by, 'assigned', now(), null, null,
    v_old_route.route_template_id, v_old_route.planned_departure_time
  )
  returning id into v_new_route_id;

  insert into public.route_plan_stops (
    route_plan_id, location_id, service_request_id, machine_id, stop_order,
    stop_kind, status, title, address_snapshot, city_snapshot,
    latitude, longitude, priority_snapshot, service_window_snapshot,
    estimated_service_minutes, note
  )
  values (
    v_new_route_id, v_old_stop.location_id, v_old_stop.service_request_id,
    v_old_stop.machine_id, v_old_stop.stop_order, v_old_stop.stop_kind,
    'planned', v_old_stop.title, v_old_stop.address_snapshot,
    v_old_stop.city_snapshot, v_old_stop.latitude, v_old_stop.longitude,
    v_old_stop.priority_snapshot, v_old_stop.service_window_snapshot,
    v_old_stop.estimated_service_minutes,
    concat_ws(' · ', nullif(v_old_stop.note, ''), 'Nová kopie po technickém resetu trasy 39.')
  );

  if (select count(*) from public.route_plan_stops where route_plan_id = v_new_route_id and status = 'planned') <> 1 then
    raise exception 'Replacement route % does not contain exactly one planned stop.', v_new_route_id;
  end if;
end
$$;

select jsonb_build_object(
  'old_route_status', (select execution_status from public.route_plans where id = 39),
  'new_route', (select to_jsonb(rp) from public.route_plans rp where rp.route_payload ->> 'reset_key' = 'urbanek-route39-mobile-sync-reset-20260807'),
  'new_stops', (select jsonb_agg(to_jsonb(s) order by s.stop_order) from public.route_plan_stops s join public.route_plans rp on rp.id = s.route_plan_id where rp.route_payload ->> 'reset_key' = 'urbanek-route39-mobile-sync-reset-20260807'),
  'movano_irish_kg', (select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id = 58 and product_id = 110),
  'movano_sophia_kg', (select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id = 58 and product_id = 108),
  'irish_container_g', (select current_quantity from public.machine_coffee_containers where id = 161),
  'sophia_container_g', (select current_quantity from public.machine_coffee_containers where id = 162)
) as result;

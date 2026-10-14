-- EV 89 / Luce X2 I/E / Sportisimo Slezská Ostrava-Hrušov.
-- Návštěvy #1249 a #1274 převedly čokoládu z vozidel do automatu, ale mobilní
-- aplikace neuložila potvrzení zásobníku Z4. Druhá návštěva fyzicky potvrdila
-- plný stav 2 000 g; její převod 2 kg do automatu proto vracíme do vozidla.

begin;

do $$
declare
  v_machine_id constant bigint := 69;
  v_container_id constant bigint := 470;
  v_product_id constant bigint := 106;
  v_machine_location_id constant bigint := 48;
  v_david_vehicle_location_id constant bigint := 2;
  v_visit_michal constant bigint := 1249;
  v_visit_david constant bigint := 1274;
  v_david_completed_at timestamptz;
  v_depletion_after_check numeric(14,3);
begin
  perform 1
  from public.machine_coffee_containers container
  where container.id = v_container_id
    and container.machine_id = v_machine_id
    and container.product_id = v_product_id
    and container.container_code = 'Z4'
    and container.capacity_quantity = 2000
    and container.unit = 'g'
    and container.active
  for update;

  if not found then
    raise exception 'EV 89 / Z4 se změnil; oprava nebyla provedena.';
  end if;

  if not exists (
    select 1 from public.route_machine_visits visit
    where visit.id = v_visit_michal
      and visit.machine_id = v_machine_id
      and visit.vehicle_id = 6
      and visit.status = 'completed'
      and visit.visit_date = date '2026-10-13'
  ) then
    raise exception 'Návštěva #1249 neodpovídá EV 89 dne 13. 10. 2026.';
  end if;

  select visit.completed_at
    into strict v_david_completed_at
  from public.route_machine_visits visit
  where visit.id = v_visit_david
    and visit.machine_id = v_machine_id
    and visit.vehicle_id = 1
    and visit.status = 'completed'
    and visit.visit_date = date '2026-10-14';

  if not exists (
    select 1 from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id like 'route_visit_1249_container_470_sync_in_%'
      and movement.product_id = v_product_id
      and movement.from_stock_location_id = 93
      and movement.to_stock_location_id = v_machine_location_id
      and movement.movement_type = 'fill_machine'
      and movement.quantity_base_units = 2
  ) or not exists (
    select 1 from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id like 'route_visit_1274_container_470_sync_in_%'
      and movement.product_id = v_product_id
      and movement.from_stock_location_id = v_david_vehicle_location_id
      and movement.to_stock_location_id = v_machine_location_id
      and movement.movement_type = 'fill_machine'
      and movement.quantity_base_units = 2
  ) then
    raise exception 'Původní skladové převody Z4 neodpovídají auditu.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id = 'route_visit_1274_container_470_sync_back_data_repair_20261014'
  ) then
    perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'batch_id', null,
      'from_stock_location_id', v_machine_location_id,
      'to_stock_location_id', v_david_vehicle_location_id,
      'movement_type', 'return',
      'quantity_base_units', 2,
      'reference_type', 'mobile_stock_request',
      'reference_id', 'route_visit_1274_container_470_sync_back_data_repair_20261014',
      'note', 'EV 89 · návštěva #1274 · operátor potvrdil plný zásobník Z4; nevsypané 2 × 1 kg vráceny do vozidla'
    )));
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items item
    where item.visit_id = v_visit_michal
      and item.coffee_container_id = v_container_id
  ) then
    insert into public.route_machine_visit_items (
      visit_id, machine_id, item_kind, coffee_container_id, physical_position_label,
      planned_product_id, planned_product_sku, planned_product_name,
      actual_product_id, actual_product_sku, actual_product_name,
      system_current_quantity, actual_before_quantity, suggested_add_quantity,
      actual_add_quantity, removed_quantity, final_quantity, capacity_quantity,
      unit, issue_type, operator_note, accepted_at
    ) values (
      v_visit_michal, v_machine_id, 'coffee_container', v_container_id, 'Z4',
      v_product_id, '47', 'oVe DRINK WITH COCOA 1 kg',
      v_product_id, '47', 'oVe DRINK WITH COCOA 1 kg',
      0, 0, 2000, 2000, 0, 2000, 2000,
      'g', 'telemetry_mismatch',
      'Manažerská oprava 14. 10. 2026: fyzicky doplněny 2 × 1 kg čokolády; mobilní potvrzení se kvůli chybě aplikace neuložilo.',
      (select completed_at from public.route_machine_visits where id = v_visit_michal)
    );
  end if;

  if not exists (
    select 1 from public.route_machine_visit_items item
    where item.visit_id = v_visit_david
      and item.coffee_container_id = v_container_id
  ) then
    insert into public.route_machine_visit_items (
      visit_id, machine_id, item_kind, coffee_container_id, physical_position_label,
      planned_product_id, planned_product_sku, planned_product_name,
      actual_product_id, actual_product_sku, actual_product_name,
      system_current_quantity, actual_before_quantity, suggested_add_quantity,
      actual_add_quantity, removed_quantity, final_quantity, capacity_quantity,
      unit, issue_type, operator_note, accepted_at
    ) values (
      v_visit_david, v_machine_id, 'coffee_container', v_container_id, 'Z4',
      v_product_id, '47', 'oVe DRINK WITH COCOA 1 kg',
      v_product_id, '47', 'oVe DRINK WITH COCOA 1 kg',
      0, 2000, 2000, 0, 0, 2000, 2000,
      'g', 'telemetry_mismatch',
      'Manažerská oprava 14. 10. 2026: operátor fyzicky potvrdil plný zásobník Z4; připravená 2 balení nebyla vložena a byla vrácena do vozidla.',
      v_david_completed_at
    );
  end if;

  update public.route_machine_visits
  set coffee_preparation = jsonb_set(
        jsonb_set(coalesce(coffee_preparation, '{}'::jsonb), '{containers,470,accepted}', 'true'::jsonb, true),
        '{containers,470,actualBeforeQuantity}', '0'::jsonb, true
      ),
      synced_at = now()
  where id = v_visit_michal;

  update public.route_machine_visits
  set coffee_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(coalesce(coffee_preparation, '{}'::jsonb), '{containers,470,accepted}', 'true'::jsonb, true),
            '{containers,470,actualBeforeQuantity}', '2000'::jsonb, true
          ),
          '{containers,470,packages}', '0'::jsonb, true
        ),
        '{containers,470,movedPackages}', '0'::jsonb, true
      ),
      synced_at = now()
  where id = v_visit_david;

  select coalesce(sum(depletion.quantity), 0)
    into v_depletion_after_check
  from public.telemetry_coffee_recipe_depletions depletion
  join public.telemetry_sales_events sale on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = v_container_id
    and sale.source_event_at >= v_david_completed_at;

  update public.machine_coffee_containers
  set current_quantity = greatest(0, 2000 - v_depletion_after_check),
      updated_at = now()
  where id = v_container_id;
end
$$;

commit;

select jsonb_build_object(
  'container', (
    select jsonb_build_object(
      'code', container.container_code,
      'current_quantity', container.current_quantity,
      'capacity_quantity', container.capacity_quantity,
      'unit', container.unit,
      'updated_at', container.updated_at
    )
    from public.machine_coffee_containers container
    where container.id = 470
  ),
  'visit_items', (
    select jsonb_agg(jsonb_build_object(
      'visit_id', item.visit_id,
      'actual_before', item.actual_before_quantity,
      'actual_add', item.actual_add_quantity,
      'final_quantity', item.final_quantity,
      'accepted_at', item.accepted_at
    ) order by item.visit_id)
    from public.route_machine_visit_items item
    where item.visit_id in (1249, 1274)
      and item.coffee_container_id = 470
  ),
  'visit_states', (
    select jsonb_agg(jsonb_build_object(
      'visit_id', visit.id,
      'cocoa', visit.coffee_preparation->'containers'->'470'
    ) order by visit.id)
    from public.route_machine_visits visit
    where visit.id in (1249, 1274)
  ),
  'repair_return', (
    select jsonb_agg(jsonb_build_object(
      'movement_id', movement.id,
      'quantity', movement.quantity_base_units,
      'from', movement.from_stock_location_id,
      'to', movement.to_stock_location_id
    ))
    from public.stock_movements_v13 movement
    where movement.reference_id = 'route_visit_1274_container_470_sync_back_data_repair_20261014'
  )
) as verification;

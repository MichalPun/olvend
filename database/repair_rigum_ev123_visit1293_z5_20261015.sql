-- RIGUM, s.r.o. / EV 123 / navsteva #1293 / Z5.
-- Operatorka fyzicky potvrdila plny zasobnik 3 000 g a doplneni 0 baleni.
-- Mobilni synchronizace vsak neulozila polozku navstevy, ponechala stav 1 608 g
-- a chybne prevedla 1 kg produktu z vozidla do automatu. Oprava doplni auditni
-- polozku, vrati nevsypane baleni do vozidla a srovna stav zasobniku na 3 000 g.

begin;

do $$
declare
  v_visit_id constant bigint := 1293;
  v_machine_id constant bigint := 101;
  v_vehicle_id constant bigint := 3;
  v_container_id constant bigint := 212;
  v_product_id constant bigint := 105;
  v_machine_location_id constant bigint := 41;
  v_vehicle_location_id constant bigint := 4;
  v_capacity constant numeric := 3000;
  v_recorded_quantity constant numeric := 1608;
  v_client_uuid constant uuid := md5('repair-rigum-visit1293-container212-20261015')::uuid;
  v_return_reference constant text := 'route_visit_1293_container_212_sync_back_data_repair_20261015';
  v_visit public.route_machine_visits%rowtype;
  v_container public.machine_coffee_containers%rowtype;
  v_draft jsonb;
  v_original_count integer;
  v_original_quantity numeric;
  v_later_items integer;
  v_later_depletions integer;
  v_return_count integer;
  v_net_machine numeric;
  v_machine_balance_before numeric;
  v_vehicle_balance_before numeric;
  v_machine_balance_after numeric;
  v_vehicle_balance_after numeric;
begin
  select * into v_visit
  from public.route_machine_visits
  where id = v_visit_id
  for update;

  if not found
     or v_visit.machine_id <> v_machine_id
     or v_visit.vehicle_id <> v_vehicle_id
     or v_visit.machine_kind <> 'coffee'
     or v_visit.status <> 'completed'
     or v_visit.visit_date <> date '2026-10-15'
     or v_visit.completed_at is null then
    raise exception 'RIGUM / EV 123 / navsteva #1293 se zmenila; oprava nebyla provedena.';
  end if;

  select * into v_container
  from public.machine_coffee_containers
  where id = v_container_id
  for update;

  if not found
     or v_container.machine_id <> v_machine_id
     or v_container.product_id <> v_product_id
     or v_container.container_code <> 'Z5'
     or v_container.capacity_quantity <> v_capacity
     or v_container.unit <> 'g'
     or not v_container.active then
    raise exception 'RIGUM / EV 123 / Z5 se zmenil; oprava nebyla provedena.';
  end if;

  if v_container.current_quantity not in (v_recorded_quantity, v_capacity) then
    raise exception 'RIGUM / Z5 ma neocekavany stav % g; oprava nebyla provedena.', v_container.current_quantity;
  end if;

  v_draft := v_visit.coffee_preparation->'containers'->v_container_id::text;
  if v_draft is null
     or coalesce((v_draft->>'accepted')::boolean, false) is not true
     or (v_draft->>'actualBeforeQuantity')::numeric <> v_capacity
     or coalesce((v_draft->>'packages')::numeric, 0) <> 0
     or coalesce((v_draft->>'movedPackages')::numeric, 0) not in (0, 1) then
    raise exception 'Fyzicke potvrzeni RIGUM / Z5 uz neodpovida auditu; oprava nebyla provedena.';
  end if;

  select count(*), coalesce(sum(movement.quantity_base_units), 0)
    into v_original_count, v_original_quantity
  from public.stock_movements_v13 movement
  where movement.reference_type = 'mobile_stock_request'
    and movement.reference_id like 'route_visit_1293_container_212_sync_in_%'
    and movement.product_id = v_product_id
    and movement.batch_id is null
    and movement.from_stock_location_id = v_vehicle_location_id
    and movement.to_stock_location_id = v_machine_location_id
    and movement.movement_type = 'fill_machine';

  if v_original_count <> 1 or v_original_quantity <> 1 then
    raise exception 'Puvodni chybny prevod RIGUM / Z5 neodpovida auditu (% zaznamu, % bal.).',
      v_original_count, v_original_quantity;
  end if;

  select count(*) into v_return_count
  from public.stock_movements_v13 movement
  where movement.reference_type = 'mobile_stock_request'
    and movement.reference_id = v_return_reference;

  if v_return_count > 1 then
    raise exception 'Opravny prevod RIGUM / Z5 je duplicitni.';
  end if;

  if v_return_count = 1 and not exists (
    select 1
    from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id = v_return_reference
      and movement.product_id = v_product_id
      and movement.batch_id is null
      and movement.from_stock_location_id = v_machine_location_id
      and movement.to_stock_location_id = v_vehicle_location_id
      and movement.movement_type = 'return'
      and movement.quantity_base_units = 1
  ) then
    raise exception 'Existujici opravny prevod RIGUM / Z5 ma jine parametry.';
  end if;

  select count(*) into v_later_items
  from public.route_machine_visit_items item
  where item.coffee_container_id = v_container_id
    and item.visit_id <> v_visit_id
    and coalesce(item.accepted_at, item.created_at) > v_visit.completed_at;

  select count(*) into v_later_depletions
  from public.telemetry_coffee_recipe_depletions depletion
  left join public.telemetry_sales_events sale on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = v_container_id
    and coalesce(sale.source_event_at, depletion.created_at) > v_visit.completed_at;

  if v_later_items <> 0 or v_later_depletions <> 0 then
    raise exception 'Po navsteve #1293 pribyla aktivita Z5 (% polozek, % telemetrickych odberu); oprava nebyla provedena.',
      v_later_items, v_later_depletions;
  end if;

  if exists (
    select 1
    from public.route_machine_visit_items item
    where item.visit_id = v_visit_id
      and item.coffee_container_id = v_container_id
      and item.client_uuid <> v_client_uuid
  ) then
    raise exception 'Navsteva #1293 uz obsahuje jinou polozku pro Z5; oprava nebyla provedena.';
  end if;

  select coalesce(sum(balance.quantity_on_hand), 0)
    into v_machine_balance_before
  from public.stock_location_balances balance
  where balance.stock_location_id = v_machine_location_id
    and balance.product_id = v_product_id
    and balance.batch_id is null;

  select coalesce(sum(balance.quantity_on_hand), 0)
    into v_vehicle_balance_before
  from public.stock_location_balances balance
  where balance.stock_location_id = v_vehicle_location_id
    and balance.product_id = v_product_id
    and balance.batch_id is null;

  if v_return_count = 0 then
    perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'batch_id', null,
      'from_stock_location_id', v_machine_location_id,
      'to_stock_location_id', v_vehicle_location_id,
      'movement_type', 'return',
      'quantity_base_units', 1,
      'reference_type', 'mobile_stock_request',
      'reference_id', v_return_reference,
      'note', 'RIGUM EV 123 · navsteva #1293 · Z5 fyzicky potvrzen plny 3000 g, doplneni 0; nevsypane 1kg baleni vraceno do vozidla'
    )));

    select coalesce(sum(balance.quantity_on_hand), 0)
      into v_machine_balance_after
    from public.stock_location_balances balance
    where balance.stock_location_id = v_machine_location_id
      and balance.product_id = v_product_id
      and balance.batch_id is null;

    select coalesce(sum(balance.quantity_on_hand), 0)
      into v_vehicle_balance_after
    from public.stock_location_balances balance
    where balance.stock_location_id = v_vehicle_location_id
      and balance.product_id = v_product_id
      and balance.batch_id is null;

    if v_machine_balance_after <> v_machine_balance_before - 1
       or v_vehicle_balance_after <> v_vehicle_balance_before + 1 then
      raise exception 'Skladovy navrat RIGUM / Z5 se nepropsal presne o 1 baleni.';
    end if;
  end if;

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
    v_visit_id, v_client_uuid, v_machine_id, 'coffee_container', v_container_id,
    v_container.container_code,
    v_product_id, v_container.product_sku, v_container.product_name,
    v_product_id, v_container.product_sku, v_container.product_name,
    v_recorded_quantity, v_capacity,
    1000, 0, 0,
    v_capacity, v_capacity, 'g',
    'telemetry_mismatch',
    'Oprava 15. 10. 2026: operatorka fyzicky potvrdila plny zasobnik 3000 g; doplneni 0. Puvodni presun 1 kg byl vracen do vozidla.',
    v_visit.completed_at
  )
  on conflict (client_uuid) do update
  set system_current_quantity = excluded.system_current_quantity,
      actual_before_quantity = excluded.actual_before_quantity,
      suggested_add_quantity = excluded.suggested_add_quantity,
      actual_add_quantity = 0,
      removed_quantity = 0,
      final_quantity = excluded.final_quantity,
      capacity_quantity = excluded.capacity_quantity,
      issue_type = excluded.issue_type,
      operator_note = excluded.operator_note,
      accepted_at = excluded.accepted_at,
      updated_at = now();

  update public.machine_coffee_containers
  set current_quantity = v_capacity,
      updated_at = now()
  where id = v_container_id;

  update public.route_machine_visits
  set coffee_preparation = jsonb_set(
        coffee_preparation,
        array['containers', v_container_id::text],
        v_draft || jsonb_build_object(
          'accepted', true,
          'actualBeforeQuantity', v_capacity,
          'packages', 0,
          'movedPackages', 0,
          'offlineStockPending', false,
          'packagesManuallyAdjusted', true,
          'stateCorrection', true,
          'stockMismatch', true
        ),
        true
      ),
      synced_at = now()
  where id = v_visit_id;

  select coalesce(sum(
    case
      when movement.to_stock_location_id = v_machine_location_id then movement.quantity_base_units
      when movement.from_stock_location_id = v_machine_location_id then -movement.quantity_base_units
      else 0
    end
  ), 0) into v_net_machine
  from public.stock_movements_v13 movement
  where movement.reference_type = 'mobile_stock_request'
    and movement.reference_id like 'route_visit_1293_container_212%';

  if v_net_machine <> 0 then
    raise exception 'Cisty skladovy pohyb RIGUM / Z5 neni po oprave nulovy: %.', v_net_machine;
  end if;

  if not exists (
    select 1
    from public.route_machine_visit_items item
    where item.visit_id = v_visit_id
      and item.client_uuid = v_client_uuid
      and item.coffee_container_id = v_container_id
      and item.system_current_quantity = v_recorded_quantity
      and item.actual_before_quantity = v_capacity
      and item.actual_add_quantity = 0
      and item.final_quantity = v_capacity
      and item.issue_type = 'telemetry_mismatch'
  ) then
    raise exception 'Auditni polozka RIGUM / Z5 nebyla ulozena spravne.';
  end if;

  if not exists (
    select 1
    from public.machine_coffee_containers container
    where container.id = v_container_id
      and container.current_quantity = v_capacity
  ) then
    raise exception 'Stav RIGUM / Z5 nebyl nastaven na 3000 g.';
  end if;
end
$$;

commit;

select jsonb_build_object(
  'visit', (
    select jsonb_build_object(
      'id', visit.id,
      'status', visit.status,
      'z5', visit.coffee_preparation->'containers'->'212'
    )
    from public.route_machine_visits visit
    where visit.id = 1293
  ),
  'container', (
    select jsonb_build_object(
      'id', container.id,
      'code', container.container_code,
      'current_quantity', container.current_quantity,
      'capacity_quantity', container.capacity_quantity,
      'unit', container.unit
    )
    from public.machine_coffee_containers container
    where container.id = 212
  ),
  'visit_item', (
    select jsonb_build_object(
      'id', item.id,
      'system_current_quantity', item.system_current_quantity,
      'actual_before_quantity', item.actual_before_quantity,
      'actual_add_quantity', item.actual_add_quantity,
      'final_quantity', item.final_quantity,
      'issue_type', item.issue_type,
      'accepted_at', item.accepted_at
    )
    from public.route_machine_visit_items item
    where item.client_uuid = md5('repair-rigum-visit1293-container212-20261015')::uuid
  ),
  'movements', (
    select jsonb_agg(jsonb_build_object(
      'id', movement.id,
      'type', movement.movement_type,
      'quantity', movement.quantity_base_units,
      'from', movement.from_stock_location_id,
      'to', movement.to_stock_location_id,
      'reference', movement.reference_id
    ) order by movement.id)
    from public.stock_movements_v13 movement
    where movement.reference_id like 'route_visit_1293_container_212%'
  ),
  'machine_balance', (
    select sum(balance.quantity_on_hand)
    from public.stock_location_balances balance
    where balance.stock_location_id = 41
      and balance.product_id = 105
      and balance.batch_id is null
  ),
  'vehicle_balance', (
    select sum(balance.quantity_on_hand)
    from public.stock_location_balances balance
    where balance.stock_location_id = 4
      and balance.product_id = 105
      and balance.batch_id is null
  )
) as verification;

-- Úklid ukázkových tras po poradě 30. 7. 2026.
-- Vrací pouze skladové a strojové změny vzniklé návštěvami označených demo tras.
-- Původní ostrá trasa 21 a její historie zůstávají zachované.

do $$
declare
  v_route_count integer;
  v_visit_count integer;
  v_container_conflicts integer;
  v_food_conflicts integer;
  v_reversal_rows jsonb;
begin
  create temporary table tmp_demo_routes on commit drop as
  select r.id
  from public.route_plans r
  where r.route_payload ->> 'demo_key' in (
    'operator-meeting-20260730',
    'operator-meeting-20260730-michal'
  );

  select count(*) into v_route_count from tmp_demo_routes;

  if v_route_count = 0 then
    raise notice 'Žádné ukázkové trasy k odstranění.';
    return;
  end if;

  create temporary table tmp_demo_visits on commit drop as
  select v.id
  from public.route_machine_visits v
  join tmp_demo_routes r on r.id = v.route_plan_id;

  select count(*) into v_visit_count from tmp_demo_visits;

  create temporary table tmp_demo_movements on commit drop as
  select sm.*
  from public.stock_movements_v13 sm
  join tmp_demo_visits v
    on sm.reference_type = 'mobile_stock_request'
   and sm.reference_id like ('route_visit_' || v.id || '_%')
  where sm.movement_type = 'fill_machine';

  select count(*) into v_container_conflicts
  from public.route_machine_visit_items i
  join tmp_demo_visits v on v.id = i.visit_id
  join public.machine_coffee_containers c on c.id = i.coffee_container_id
  where i.item_kind = 'coffee_container'
    and coalesce(i.actual_add_quantity, 0) > 0
    and c.current_quantity is distinct from i.final_quantity;

  if v_container_conflicts <> 0 then
    raise exception
      'Nelze bezpečně vrátit demo změny: % zásobníků se mezitím změnilo.',
      v_container_conflicts;
  end if;

  select count(*) into v_food_conflicts
  from public.route_machine_visit_items i
  join tmp_demo_visits v on v.id = i.visit_id
  join public.machine_planogram_slots s on s.id = i.planogram_slot_id
  where i.item_kind = 'food_slot'
    and i.final_quantity is distinct from i.system_current_quantity
    and s.current_units is distinct from i.final_quantity;

  if v_food_conflicts <> 0 then
    raise exception
      'Nelze bezpečně vrátit demo změny: % potravinových pozic se mezitím změnilo.',
      v_food_conflicts;
  end if;

  select jsonb_agg(jsonb_build_object(
    'product_id', sm.product_id,
    'batch_id', sm.batch_id,
    'from_stock_location_id', sm.to_stock_location_id,
    'to_stock_location_id', sm.from_stock_location_id,
    'movement_type', 'return',
    'quantity_base_units', sm.quantity_base_units,
    'reference_type', 'mobile_stock_request',
    'reference_id', 'demo_cleanup_stock_movement_' || sm.id,
    'note', 'Vrácení zkušebního pohybu po poradě · původní pohyb ' || sm.id
  ) order by sm.id)
  into v_reversal_rows
  from tmp_demo_movements sm
  where not exists (
    select 1
    from public.stock_movements_v13 cleanup
    where cleanup.reference_type = 'mobile_stock_request'
      and cleanup.reference_id = 'demo_cleanup_stock_movement_' || sm.id
  );

  if v_reversal_rows is not null then
    perform public.apply_stock_movements_v13(v_reversal_rows);
  end if;

  update public.machine_coffee_containers c
  set
    current_quantity = i.system_current_quantity,
    updated_at = now()
  from public.route_machine_visit_items i
  join tmp_demo_visits v on v.id = i.visit_id
  where i.item_kind = 'coffee_container'
    and i.coffee_container_id = c.id
    and coalesce(i.actual_add_quantity, 0) > 0
    and c.current_quantity is not distinct from i.final_quantity;

  update public.machine_planogram_slots s
  set
    current_units = i.system_current_quantity,
    updated_at = now()
  from public.route_machine_visit_items i
  join tmp_demo_visits v on v.id = i.visit_id
  where i.item_kind = 'food_slot'
    and i.planogram_slot_id = s.id
    and i.final_quantity is distinct from i.system_current_quantity
    and s.current_units is not distinct from i.final_quantity;

  delete from public.route_machine_visits
  where id in (select id from tmp_demo_visits);

  delete from public.route_plans
  where id in (select id from tmp_demo_routes);

  if exists (
    select 1
    from public.route_plans r
    where r.route_payload ->> 'demo_key' in (
      'operator-meeting-20260730',
      'operator-meeting-20260730-michal'
    )
  ) then
    raise exception 'Některé ukázkové trasy po úklidu zůstaly.';
  end if;

  raise notice
    'Odstraněno ukázkových tras: %, návštěv: %.',
    v_route_count,
    v_visit_count;
end
$$;

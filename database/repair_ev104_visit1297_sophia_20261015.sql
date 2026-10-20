-- Repair the physical Z5 observation that the mobile client acknowledged
-- locally on 2026-10-15 but never persisted because it queued a UUID into a
-- bigint primary key. The observed full state is anchored to the stop's real
-- completion time; the observation trigger reapplies all later sales.

begin;

create table if not exists public.repair_ev104_visit1297_audit_20261015 (
  repair_key text primary key,
  before_state jsonb not null,
  after_state jsonb,
  repaired_at timestamptz not null default now()
);

-- Internal rollback evidence only. It must never be reachable from a client
-- session, even by an authenticated employee account.
alter table public.repair_ev104_visit1297_audit_20261015 enable row level security;
revoke all on table public.repair_ev104_visit1297_audit_20261015 from public, anon, authenticated;

do $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_stop public.route_plan_stops%rowtype;
  v_container public.machine_coffee_containers%rowtype;
  v_item public.route_machine_visit_items%rowtype;
  v_before jsonb;
  v_after jsonb;
  v_depletion numeric(14,3);
  v_expected numeric(14,3);
  v_stock_result jsonb;
begin
  select * into strict v_visit
  from public.route_machine_visits
  where id = 1297
    and route_plan_id = 155
    and route_plan_stop_id = 1858
    and machine_id = 84
  for update;

  select * into strict v_stop
  from public.route_plan_stops
  where id = 1858
    and route_plan_id = 155
    and machine_id = 84
  for update;

  select * into strict v_container
  from public.machine_coffee_containers
  where id = 665
    and machine_id = 84
    and container_code = 'Z5'
    and product_sku = '44'
    and active
  for update;

  if v_stop.status <> 'done' or v_stop.completed_at is null then
    raise exception 'EV104 stop 1858 is not a completed stop.';
  end if;
  if v_visit.status not in ('arrived', 'completed') then
    raise exception 'EV104 visit 1297 has unexpected status %.', v_visit.status;
  end if;
  if v_visit.status = 'completed'
     and v_visit.completed_at is distinct from v_stop.completed_at then
    raise exception 'EV104 visit 1297 has a different completion time than stop 1858.';
  end if;
  if v_container.capacity_quantity <> 1500 or v_container.unit <> 'g' then
    raise exception 'EV104 Z5 capacity/unit changed: % %.',
      v_container.capacity_quantity, v_container.unit;
  end if;

  if exists (
    select 1
    from public.route_machine_visit_items
    where visit_id = v_visit.id
      and coffee_container_id = v_container.id
      and client_uuid <> '12970000-0000-4000-8000-000000000665'::uuid
  ) then
    raise exception 'EV104 Z5 already has another visit item; refusing to overwrite it.';
  end if;

  v_before := jsonb_build_object(
    'visit', to_jsonb(v_visit),
    'stop', to_jsonb(v_stop),
    'container', to_jsonb(v_container),
    'existing_item', (
      select to_jsonb(item)
      from public.route_machine_visit_items item
      where item.client_uuid = '12970000-0000-4000-8000-000000000665'::uuid
    ),
    'stock_movements', (
      select coalesce(jsonb_agg(to_jsonb(movement) order by movement.created_at), '[]'::jsonb)
      from public.stock_movements_v13 movement
      where movement.product_id = v_container.product_id
        and movement.reference_type = 'mobile_stock_request'
        and (
          movement.reference_id like 'route_visit_1297_container_665%'
          or movement.reference_id = 'repair_ev104_visit1297_z5_return'
        )
    )
  );

  insert into public.repair_ev104_visit1297_audit_20261015
    (repair_key, before_state)
  values ('ev104-z5-2026-10-15', v_before)
  on conflict (repair_key) do nothing;

  insert into public.route_machine_visit_items (
    visit_id,
    client_uuid,
    machine_id,
    item_kind,
    coffee_container_id,
    physical_position_label,
    planned_product_id,
    planned_product_sku,
    planned_product_name,
    actual_product_id,
    actual_product_sku,
    actual_product_name,
    system_current_quantity,
    actual_before_quantity,
    suggested_add_quantity,
    actual_add_quantity,
    removed_quantity,
    final_quantity,
    capacity_quantity,
    unit,
    issue_type,
    operator_note,
    accepted_at
  ) values (
    v_visit.id,
    '12970000-0000-4000-8000-000000000665'::uuid,
    v_container.machine_id,
    'coffee_container',
    v_container.id,
    v_container.container_code,
    v_container.product_id,
    v_container.product_sku,
    v_container.product_name,
    v_container.product_id,
    v_container.product_sku,
    v_container.product_name,
    0,
    v_container.capacity_quantity,
    0,
    0,
    0,
    v_container.capacity_quantity,
    v_container.capacity_quantity,
    v_container.unit,
    'telemetry_mismatch',
    'Obnova ztraceného fyzického zápisu: Michal Punčochář nastavil Z5 na 100 %; čas převzat z dokončení zastávky.',
    v_stop.completed_at
  )
  on conflict (client_uuid) do update
  set final_quantity = excluded.final_quantity,
      actual_before_quantity = excluded.actual_before_quantity,
      accepted_at = excluded.accepted_at,
      operator_note = excluded.operator_note,
      updated_at = now()
  returning * into v_item;

  select coalesce(sum(depletion.quantity), 0)::numeric(14,3)
    into v_depletion
  from public.telemetry_coffee_recipe_depletions depletion
  join public.telemetry_sales_events sale
    on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = v_container.id
    and sale.source_event_at > v_stop.completed_at;

  v_expected := greatest(0, v_container.capacity_quantity - v_depletion);

  select * into strict v_container
  from public.machine_coffee_containers
  where id = 665
  for update;

  if v_container.current_quantity is distinct from v_expected then
    raise exception 'EV104 Z5 repair mismatch: expected %, got %.',
      v_expected, v_container.current_quantity;
  end if;
  if v_container.physical_count_visit_item_id is distinct from v_item.id
     or v_container.physical_counted_at is distinct from v_stop.completed_at then
    raise exception 'EV104 Z5 physical observation watermark was not persisted.';
  end if;

  -- The picklist moved one 500 g package from the car to the machine before
  -- Michal found the container physically full. Return that unopened package
  -- to the same vehicle stock and make the saved preparation match reality.
  if (
    select coalesce(sum(movement.quantity_base_units), 0)
    from public.stock_movements_v13 movement
    where movement.product_id = v_container.product_id
      and movement.reference_type = 'mobile_stock_request'
      and movement.reference_id like 'route_visit_1297_container_665%'
      and movement.movement_type = 'fill_machine'
      and movement.from_stock_location_id = 93
      and movement.to_stock_location_id = 90
  ) <> 0.5 then
    raise exception 'EV104 Z5 original vehicle movement is no longer exactly 0.5 kg.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id = 'repair_ev104_visit1297_z5_return'
  ) then
    select public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_container.product_id,
      'batch_id', null,
      'from_stock_location_id', 90,
      'to_stock_location_id', 93,
      'movement_type', 'return',
      'quantity_base_units', 0.5,
      'reference_type', 'mobile_stock_request',
      'reference_id', 'repair_ev104_visit1297_z5_return',
      'created_by', v_visit.employee_id,
      'note', 'Oprava EV104 Z5: zásobník byl fyzicky plný, neotevřené balení se vrací do Fiat Doblò 3BU9736.'
    ))) into v_stock_result;
  end if;

  update public.route_machine_visits
  set coffee_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  coalesce(coffee_preparation, '{}'::jsonb),
                  '{containers,665,accepted}', 'true'::jsonb, true
                ),
                '{containers,665,packages}', '0'::jsonb, true
              ),
              '{containers,665,movedPackages}', '0'::jsonb, true
            ),
            '{containers,665,pickDecision}', '"skipped"'::jsonb, true
          ),
          '{containers,665,pickSkipReason}', '"Zásobník byl fyzicky plný"'::jsonb, true
        ),
        '{containers,665,stockMismatch}', 'false'::jsonb, true
      ),
      updated_at = now()
  where id = v_visit.id;

  -- Complete the visit only after the lost container observation exists. The
  -- production completion guard correctly refuses a coffee visit without all
  -- required container confirmations.
  update public.route_machine_visits
  set status = 'completed',
      completed_at = v_stop.completed_at,
      synced_at = greatest(coalesce(synced_at, v_stop.completed_at), v_stop.completed_at),
      updated_at = now()
  where id = v_visit.id;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 1297;

  if v_visit.status <> 'completed'
     or v_visit.completed_at is distinct from v_stop.completed_at then
    raise exception 'EV104 visit 1297 could not be synchronized with stop 1858.';
  end if;

  v_after := jsonb_build_object(
    'visit', (
      select to_jsonb(visit) from public.route_machine_visits visit where visit.id = 1297
    ),
    'stop', (
      select to_jsonb(stop) from public.route_plan_stops stop where stop.id = 1858
    ),
    'container', to_jsonb(v_container),
    'visit_item', to_jsonb(v_item),
    'recorded_depletion_after_visit', v_depletion,
    'expected_quantity', v_expected,
    'stock_return_result', v_stock_result,
    'stock_return', (
      select to_jsonb(movement)
      from public.stock_movements_v13 movement
      where movement.reference_type = 'mobile_stock_request'
        and movement.reference_id = 'repair_ev104_visit1297_z5_return'
      limit 1
    )
  );

  update public.repair_ev104_visit1297_audit_20261015
  set after_state = v_after,
      repaired_at = now()
  where repair_key = 'ev104-z5-2026-10-15';
end $$;

commit;

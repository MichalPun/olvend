-- Context pro nulové stavy na nástěnce:
-- kdy proběhl poslední úspěšný výdej a co se s pozicí dělo potom.

create index if not exists telemetry_sales_events_planogram_slot_source_idx
  on public.telemetry_sales_events (planogram_slot_id, source_event_at desc)
  where planogram_slot_id is not null;

create index if not exists machine_coffee_recipe_items_container_idx
  on public.machine_coffee_recipe_items (coffee_container_id, coffee_button_id)
  where active = true;

create index if not exists route_machine_visit_items_planogram_slot_idx
  on public.route_machine_visit_items (planogram_slot_id, visit_id)
  where planogram_slot_id is not null;

create index if not exists route_machine_visit_items_coffee_container_idx
  on public.route_machine_visit_items (coffee_container_id, visit_id)
  where coffee_container_id is not null;

create index if not exists route_machine_visits_machine_completed_idx
  on public.route_machine_visits (machine_id, completed_at desc)
  where status = 'completed';

create or replace function public.get_low_stock_depletion_context_v25(
  p_food_slot_ids bigint[] default array[]::bigint[],
  p_coffee_container_ids bigint[] default array[]::bigint[]
)
returns table (
  item_kind text,
  item_id bigint,
  machine_id bigint,
  sold_out_at timestamptz,
  last_visit_at timestamptz,
  last_replenished_at timestamptz,
  last_replenished_quantity numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  with requested_food as (
    select
      'food_slot'::text as item_kind,
      slot.id as item_id,
      slot.machine_id
    from public.machine_planogram_slots slot
    where slot.id = any(coalesce(p_food_slot_ids, array[]::bigint[]))
      and slot.active = true
      and coalesce(slot.current_units, 0) <= 0
  ),
  requested_coffee as (
    select
      'coffee_container'::text as item_kind,
      container.id as item_id,
      container.machine_id
    from public.machine_coffee_containers container
    where container.id = any(coalesce(p_coffee_container_ids, array[]::bigint[]))
      and container.active = true
      and coalesce(container.current_quantity, 0) <= 0
  ),
  food_last_sales as (
    select
      requested.item_id,
      max(sale.source_event_at) as sold_out_at
    from requested_food requested
    join public.telemetry_sales_events sale
      on sale.planogram_slot_id = requested.item_id
     and coalesce(sale.quantity, 0) > 0
    group by requested.item_id
  ),
  coffee_last_sales as (
    select
      requested.item_id,
      max(sale.source_event_at) as sold_out_at
    from requested_coffee requested
    join public.machine_coffee_recipe_items recipe
      on recipe.coffee_container_id = requested.item_id
     and recipe.active = true
    join public.machine_coffee_buttons button
      on button.id = recipe.coffee_button_id
     and button.active = true
    join public.telemetry_sales_events sale
      on sale.machine_id = requested.machine_id
     and sale.selection_code = button.selection_code
     and coalesce(sale.quantity, 0) > 0
    group by requested.item_id
  ),
  depleted as (
    select requested.*, sale.sold_out_at
    from requested_food requested
    left join food_last_sales sale using (item_id)

    union all

    select requested.*, sale.sold_out_at
    from requested_coffee requested
    left join coffee_last_sales sale using (item_id)
  )
  select
    depleted.item_kind,
    depleted.item_id,
    depleted.machine_id,
    depleted.sold_out_at,
    visit.last_visit_at,
    refill.last_replenished_at,
    refill.last_replenished_quantity
  from depleted
  left join lateral (
    select coalesce(machine_visit.completed_at, machine_visit.updated_at) as last_visit_at
    from public.route_machine_visits machine_visit
    where machine_visit.machine_id = depleted.machine_id
      and machine_visit.status = 'completed'
      and depleted.sold_out_at is not null
      and coalesce(machine_visit.completed_at, machine_visit.updated_at) > depleted.sold_out_at
    order by coalesce(machine_visit.completed_at, machine_visit.updated_at) desc
    limit 1
  ) visit on true
  left join lateral (
    select
      coalesce(visit_item.accepted_at, machine_visit.completed_at, visit_item.updated_at) as last_replenished_at,
      visit_item.actual_add_quantity as last_replenished_quantity
    from public.route_machine_visit_items visit_item
    join public.route_machine_visits machine_visit
      on machine_visit.id = visit_item.visit_id
     and machine_visit.status = 'completed'
    where visit_item.machine_id = depleted.machine_id
      and coalesce(visit_item.actual_add_quantity, 0) > 0
      and depleted.sold_out_at is not null
      and coalesce(visit_item.accepted_at, machine_visit.completed_at, visit_item.updated_at) > depleted.sold_out_at
      and (
        (depleted.item_kind = 'food_slot' and visit_item.planogram_slot_id = depleted.item_id)
        or (depleted.item_kind = 'coffee_container' and visit_item.coffee_container_id = depleted.item_id)
      )
    order by coalesce(visit_item.accepted_at, machine_visit.completed_at, visit_item.updated_at) desc
    limit 1
  ) refill on true;
$$;

revoke all on function public.get_low_stock_depletion_context_v25(bigint[], bigint[]) from public, anon;
grant execute on function public.get_low_stock_depletion_context_v25(bigint[], bigint[]) to authenticated;

comment on function public.get_low_stock_depletion_context_v25(bigint[], bigint[]) is
  'Pro zadané nulové pozice vrátí poslední telemetrický výdej, poslední dokončenou návštěvu a skutečné doplnění po vyprodání.';

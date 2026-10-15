-- Physical coffee-container observations are the authoritative inventory baseline.
-- A delayed telemetry event that happened before the observation must never
-- subtract from that baseline. Offline observations may arrive after newer sales,
-- so the trigger also reapplies already recorded post-observation depletion.

begin;

alter table public.machine_coffee_containers
  add column if not exists physical_counted_at timestamptz,
  add column if not exists physical_count_source text,
  add column if not exists physical_count_visit_item_id bigint
    references public.route_machine_visit_items (id) on delete set null;

create index if not exists machine_coffee_containers_physical_counted_idx
  on public.machine_coffee_containers (physical_counted_at desc)
  where physical_counted_at is not null;

create or replace function public.apply_coffee_container_physical_observation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_observed_at timestamptz;
  v_depleted_after numeric(14,3) := 0;
  v_updated integer := 0;
begin
  if new.item_kind <> 'coffee_container'
     or new.coffee_container_id is null
     or new.final_quantity is null
     or new.accepted_at is null then
    return new;
  end if;

  -- Keep the real offline observation time but do not allow a bad device clock
  -- to create a future watermark that would suppress genuine sales.
  v_observed_at := least(new.accepted_at, now());

  -- Serialize a physical observation with telemetry depletion for the same
  -- container. Without this lock, two concurrent transactions could both read
  -- the old quantity and the later commit could hide the other's change.
  perform 1
  from public.machine_coffee_containers container
  where container.id = new.coffee_container_id
    and container.machine_id = new.machine_id
  for update;

  if not found then
    raise exception 'Coffee container % does not belong to machine %.',
      new.coffee_container_id, new.machine_id;
  end if;

  select coalesce(sum(depletion.quantity), 0)::numeric(14,3)
    into v_depleted_after
  from public.telemetry_coffee_recipe_depletions depletion
  join public.telemetry_sales_events sale
    on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = new.coffee_container_id
    and sale.source_event_at > v_observed_at;

  update public.machine_coffee_containers container
  set current_quantity = greatest(0, new.final_quantity - v_depleted_after),
      physical_counted_at = v_observed_at,
      physical_count_source = 'route_visit',
      physical_count_visit_item_id = new.id,
      updated_at = now()
  where container.id = new.coffee_container_id
    and container.machine_id = new.machine_id
    and (
      container.physical_counted_at is null
      or v_observed_at > container.physical_counted_at
      or container.physical_count_visit_item_id = new.id
    );

  get diagnostics v_updated = row_count;
  if v_updated = 0 and not exists (
    select 1
    from public.machine_coffee_containers container
    where container.id = new.coffee_container_id
      and container.machine_id = new.machine_id
  ) then
    raise exception 'Coffee container % does not belong to machine %.',
      new.coffee_container_id, new.machine_id;
  end if;

  return new;
end $$;

drop trigger if exists trg_route_visit_item_coffee_observation
  on public.route_machine_visit_items;

create trigger trg_route_visit_item_coffee_observation
after insert or update of item_kind, final_quantity, accepted_at, coffee_container_id, machine_id
on public.route_machine_visit_items
for each row
when (
  new.item_kind = 'coffee_container'
  and new.coffee_container_id is not null
  and new.final_quantity is not null
  and new.accepted_at is not null
)
execute function public.apply_coffee_container_physical_observation();

-- Existing accepted observations establish the watermark only. Their current
-- quantities are left untouched here; targeted reconciliation is performed from
-- the audit trail so this migration cannot invent stock on unrelated machines.
with latest as (
  select distinct on (item.coffee_container_id)
    item.coffee_container_id,
    least(item.accepted_at, now()) as observed_at,
    item.id as visit_item_id
  from public.route_machine_visit_items item
  where item.item_kind = 'coffee_container'
    and item.coffee_container_id is not null
    and item.final_quantity is not null
    and item.accepted_at is not null
  order by item.coffee_container_id, item.accepted_at desc, item.id desc
)
update public.machine_coffee_containers container
set physical_counted_at = latest.observed_at,
    physical_count_source = 'route_visit_backfill',
    physical_count_visit_item_id = latest.visit_item_id,
    updated_at = now()
from latest
where container.id = latest.coffee_container_id
  and (
    container.physical_counted_at is null
    or latest.observed_at > container.physical_counted_at
  );

create or replace function public.apply_telemetry_coffee_depletion(p_sale_event_ids bigint[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
  v_containers integer := 0;
begin
  with targets as (
    select
      sale.id as sale_event_id,
      recipe.id as recipe_item_id,
      container.id as coffee_container_id,
      container.unit,
      round((case
        when lower(recipe.unit) = lower(container.unit) then recipe.quantity_per_vend * sale.quantity
        when lower(recipe.unit) = 'kg' and lower(container.unit) = 'g' then recipe.quantity_per_vend * sale.quantity * 1000
        when lower(recipe.unit) = 'g' and lower(container.unit) = 'kg' then recipe.quantity_per_vend * sale.quantity / 1000
        when lower(recipe.unit) = 'l' and lower(container.unit) = 'ml' then recipe.quantity_per_vend * sale.quantity * 1000
        when lower(recipe.unit) = 'ml' and lower(container.unit) = 'l' then recipe.quantity_per_vend * sale.quantity / 1000
        else recipe.quantity_per_vend * sale.quantity end)::numeric, 3) as target_quantity
    from public.telemetry_sales_events sale
    join public.machine_coffee_buttons button
      on button.machine_id = sale.machine_id
     and button.active
     and button.selection_code = sale.selection_code
    join public.machine_coffee_recipe_items recipe
      on recipe.machine_id = sale.machine_id
     and recipe.coffee_button_id = button.id
     and recipe.active
    join public.machine_coffee_containers container
      on container.id = recipe.coffee_container_id
     and container.machine_id = sale.machine_id
     and container.active
    where sale.id = any(p_sale_event_ids)
      and sale.quantity > 0
      and recipe.quantity_per_vend > 0
      and sale.source_event_at > coalesce(container.physical_counted_at, '-infinity'::timestamptz)
  ), deltas as (
    select
      target.*,
      greatest(0, target.target_quantity - coalesce(existing.quantity, 0))::numeric(14,3) as quantity
    from targets target
    left join public.telemetry_coffee_recipe_depletions existing
      on existing.sale_event_id = target.sale_event_id
     and existing.recipe_item_id = target.recipe_item_id
  ), applied as (
    insert into public.telemetry_coffee_recipe_depletions
      (sale_event_id, recipe_item_id, coffee_container_id, quantity, unit)
    select sale_event_id, recipe_item_id, coffee_container_id, quantity, unit
    from deltas
    where quantity > 0
    on conflict (sale_event_id, recipe_item_id) do update
      set quantity = public.telemetry_coffee_recipe_depletions.quantity + excluded.quantity
    returning coffee_container_id
  ), usage as (
    select coffee_container_id, sum(quantity) as quantity
    from deltas
    where quantity > 0
    group by coffee_container_id
  ), updated as (
    update public.machine_coffee_containers container
    set current_quantity = greatest(0, container.current_quantity - usage.quantity),
        updated_at = now()
    from usage
    where container.id = usage.coffee_container_id
    returning container.id
  )
  select (select count(*) from applied), (select count(*) from updated)
  into v_inserted, v_containers;

  return jsonb_build_object(
    'inserted', v_inserted,
    'containers_updated', v_containers
  );
end $$;

revoke all on function public.apply_telemetry_coffee_depletion(bigint[]) from public;
grant execute on function public.apply_telemetry_coffee_depletion(bigint[]) to service_role;

commit;

-- Unpaid DEX attempts are possible stock losses, not confirmed inventory depletion.
-- Confirmed payment arriving later can still apply the missing incremental depletion.
begin;

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
      s.id as sale_event_id,
      ri.id as recipe_item_id,
      c.id as coffee_container_id,
      c.unit,
      round((case
        when lower(ri.unit) = lower(c.unit) then ri.quantity_per_vend * confirmed.quantity
        when lower(ri.unit) = 'kg' and lower(c.unit) = 'g' then ri.quantity_per_vend * confirmed.quantity * 1000
        when lower(ri.unit) = 'g' and lower(c.unit) = 'kg' then ri.quantity_per_vend * confirmed.quantity / 1000
        when lower(ri.unit) = 'l' and lower(c.unit) = 'ml' then ri.quantity_per_vend * confirmed.quantity * 1000
        when lower(ri.unit) = 'ml' and lower(c.unit) = 'l' then ri.quantity_per_vend * confirmed.quantity / 1000
        else ri.quantity_per_vend * confirmed.quantity end)::numeric, 3) as target_quantity
    from public.telemetry_sales_events s
    cross join lateral (
      select greatest(0,
        coalesce(s.cash_quantity, 0)
        + coalesce(s.cashless_quantity, 0)
        + coalesce(s.unknown_payment_quantity, 0)
      ) as quantity
    ) confirmed
    join public.machine_coffee_buttons b
      on b.machine_id = s.machine_id and b.active and b.selection_code = s.selection_code
    join public.machine_coffee_recipe_items ri
      on ri.machine_id = s.machine_id and ri.coffee_button_id = b.id and ri.active
    join public.machine_coffee_containers c
      on c.id = ri.coffee_container_id and c.machine_id = s.machine_id and c.active
    where s.id = any(p_sale_event_ids) and confirmed.quantity > 0 and ri.quantity_per_vend > 0
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
    update public.machine_coffee_containers c
    set current_quantity = greatest(0, c.current_quantity - usage.quantity), updated_at = now()
    from usage
    where c.id = usage.coffee_container_id
    returning c.id
  )
  select (select count(*) from applied), (select count(*) from updated)
  into v_inserted, v_containers;

  return jsonb_build_object('inserted', v_inserted, 'containers_updated', v_containers);
end $$;

revoke all on function public.apply_telemetry_coffee_depletion(bigint[]) from public;
grant execute on function public.apply_telemetry_coffee_depletion(bigint[]) to service_role;

create or replace function public.apply_telemetry_stock_depletion(p_sale_event_ids bigint[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer := 0;
  v_events integer := 0;
begin
  with event_targets as (
    select
      s.id as sale_event_id,
      sl.id as stock_location_id,
      p.id as product_id,
      greatest(0,
        coalesce(s.cash_quantity, 0)
        + coalesce(s.cashless_quantity, 0)
        + coalesce(s.unknown_payment_quantity, 0)
        - coalesce(existing.quantity, 0)
      )::numeric(14,3) as quantity
    from public.telemetry_sales_events s
    join public.products p on p.sku = s.product_sku
    join public.stock_locations sl on sl.location_type = 'machine' and sl.machine_id = s.machine_id
    left join lateral (
      select sum(d.quantity) as quantity
      from public.telemetry_stock_depletions d
      where d.sale_event_id = s.id and d.product_id = p.id
    ) existing on true
    where s.id = any(p_sale_event_ids)
  ), candidates as materialized (
    select
      target.sale_event_id,
      target.stock_location_id,
      target.product_id,
      balance.batch_id,
      least(balance.quantity_on_hand, greatest(0, target.quantity -
        coalesce(sum(balance.quantity_on_hand) over (
          partition by target.sale_event_id
          order by coalesce(batch.use_by_date, batch.best_before_date, '9999-12-31'::date), balance.id
          rows between unbounded preceding and 1 preceding
        ), 0)
      ))::numeric(14,3) as quantity
    from event_targets target
    join public.stock_location_balances balance
      on balance.stock_location_id = target.stock_location_id
      and balance.product_id = target.product_id
      and balance.quantity_on_hand > 0
    left join public.inventory_batches batch on batch.id = balance.batch_id
    where target.quantity > 0
  ), recorded as (
    insert into public.telemetry_stock_depletions
      (sale_event_id, stock_location_id, product_id, batch_id, quantity)
    select sale_event_id, stock_location_id, product_id, batch_id, quantity
    from candidates
    where quantity > 0
    on conflict (sale_event_id, product_id, batch_id) do update
      set quantity = public.telemetry_stock_depletions.quantity + excluded.quantity
    returning sale_event_id
  ), balance_usage as (
    select stock_location_id, product_id, batch_id, sum(quantity) as quantity
    from candidates
    where quantity > 0
    group by stock_location_id, product_id, batch_id
  ), updated as (
    update public.stock_location_balances balance
    set quantity_on_hand = balance.quantity_on_hand - usage.quantity, updated_at = now()
    from balance_usage usage
    where balance.stock_location_id = usage.stock_location_id
      and balance.product_id = usage.product_id
      and balance.batch_id is not distinct from usage.batch_id
    returning balance.id
  ), movements as (
    insert into public.stock_movements_v13
      (product_id, batch_id, from_stock_location_id, to_stock_location_id, movement_type,
       quantity_base_units, reference_type, reference_id, note)
    select
      product_id, batch_id, stock_location_id, null, 'sale', quantity,
      'telemetry_sale', 'telemetry-sale:' || sale_event_id,
      'Potvrzený telemetrický prodej #' || sale_event_id
    from candidates
    where quantity > 0
    returning id
  )
  select count(*), count(distinct sale_event_id)
  into v_rows, v_events
  from candidates
  where quantity > 0;

  return jsonb_build_object('inserted', v_rows, 'sale_events', v_events);
end $$;

revoke all on function public.apply_telemetry_stock_depletion(bigint[]) from public;
grant execute on function public.apply_telemetry_stock_depletion(bigint[]) to service_role;

-- Restore already depleted stock for today's events that are now fully unpaid.
create temporary table possible_loss_restore_20260803 on commit drop as
select
  depletion.id as depletion_id,
  depletion.sale_event_id,
  depletion.stock_location_id,
  depletion.product_id,
  depletion.batch_id,
  depletion.quantity
from public.telemetry_stock_depletions depletion
join public.telemetry_sales_events sale on sale.id = depletion.sale_event_id
where sale.source_event_at >= timestamptz '2026-08-03 00:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-04 00:00:00+00'
  and sale.unpaid_dispense_quantity > 0
  and coalesce(sale.cash_quantity, 0) + coalesce(sale.cashless_quantity, 0) + coalesce(sale.unknown_payment_quantity, 0) = 0;

do $$
declare
  v_quantity numeric;
begin
  select coalesce(sum(quantity), 0) into v_quantity from possible_loss_restore_20260803;
  if v_quantity <> 11 then
    raise exception 'Expected to restore 11 possible-loss units, found %', v_quantity;
  end if;
end $$;

with restored as (
  select stock_location_id, product_id, batch_id, sum(quantity) as quantity
  from possible_loss_restore_20260803
  group by stock_location_id, product_id, batch_id
)
update public.stock_location_balances balance
set quantity_on_hand = balance.quantity_on_hand + restored.quantity, updated_at = now()
from restored
where balance.stock_location_id = restored.stock_location_id
  and balance.product_id = restored.product_id
  and balance.batch_id is not distinct from restored.batch_id;

insert into public.stock_movements_v13
  (product_id, batch_id, from_stock_location_id, to_stock_location_id, movement_type,
   quantity_base_units, reference_type, reference_id, note)
select
  product_id, batch_id, null, stock_location_id, 'adjustment', quantity,
  'telemetry_possible_stock_loss', 'telemetry-possible-loss:' || sale_event_id || ':' || depletion_id,
  'Vrácení tvrdého odečtu: možný úbytek bez platby #' || sale_event_id
from possible_loss_restore_20260803;

delete from public.telemetry_stock_depletions depletion
using possible_loss_restore_20260803 restored
where depletion.id = restored.depletion_id;

commit;

create or replace view public.telemetry_possible_stock_losses as
select
  sale.id as sale_event_id,
  sale.machine_id,
  machine.evidence_number,
  machine.location_id,
  sale.selection_code,
  sale.product_sku,
  sale.product_name,
  sale.unpaid_dispense_quantity as possible_quantity,
  sale.source_event_at,
  sale.created_at
from public.telemetry_sales_events sale
join public.machines machine on machine.id = sale.machine_id
where sale.unpaid_dispense_quantity > 0;

grant select on public.telemetry_possible_stock_losses to authenticated;

select
  m.evidence_number,
  sum(s.unpaid_dispense_quantity) as possible_stock_loss,
  coalesce(sum(d.quantity), 0) as hard_depletion_remaining
from public.telemetry_sales_events s
join public.machines m on m.id = s.machine_id
left join public.telemetry_stock_depletions d on d.sale_event_id = s.id
where s.source_event_at >= timestamptz '2026-08-03 00:00:00+00'
  and s.source_event_at < timestamptz '2026-08-04 00:00:00+00'
  and s.unpaid_dispense_quantity > 0
group by m.evidence_number
order by m.evidence_number;

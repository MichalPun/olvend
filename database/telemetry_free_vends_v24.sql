-- Zero-price IMA vends are confirmed free/subsidised sales. They have no payment
-- counter delta and must never be reported as unknown or possible stock loss.
begin;

alter table public.telemetry_sales_events
  add column if not exists free_vend_quantity numeric(12,3) not null default 0;

comment on column public.telemetry_sales_events.free_vend_quantity is
  'Confirmed zero-price/free/subsidised vends which correctly have no cash or card counter delta.';

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
        + coalesce(s.free_vend_quantity, 0)
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
        + coalesce(s.free_vend_quantity, 0)
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

create temporary table reclassified_free_vends on commit drop as
select sale.id, sale.source_event_at
from public.telemetry_sales_events sale
join public.machine_planogram_slots slot on slot.id = sale.planogram_slot_id
where sale.provider = 'IMA'
  and coalesce(slot.customer_price_czk, slot.dex_price_czk) = 0
  and sale.quantity > 0
  and sale.source_event_at >= timestamptz '2026-08-03 22:00:00+00'
  and sale.source_event_at <  timestamptz '2026-08-04 22:00:00+00'
  and sale.free_vend_quantity <> sale.quantity;

update public.telemetry_sales_events sale
set
  cash_quantity = 0,
  cashless_quantity = 0,
  free_vend_quantity = sale.quantity,
  unknown_payment_quantity = 0,
  unpaid_dispense_quantity = 0,
  cash_amount_czk = 0,
  cashless_amount_czk = 0,
  unknown_payment_amount_czk = 0,
  unit_price_czk = 0,
  total_amount_czk = 0
from reclassified_free_vends target
where sale.id = target.id;

do $$
declare
  v_ids bigint[];
begin
  -- Apply the newly confirmed depletion only to the live incident window. Older
  -- rows may already be covered by a later physical inventory, so changing their
  -- reporting classification must not rewrite today's physical balance.
  select array_agg(id order by id)
  into v_ids
  from reclassified_free_vends
  where source_event_at >= timestamptz '2026-08-04 16:00:00+00';
  if coalesce(cardinality(v_ids), 0) > 0 then
    perform public.apply_telemetry_coffee_depletion(v_ids);
    perform public.apply_telemetry_stock_depletion(v_ids);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from public.telemetry_sales_events sale
    join public.machine_planogram_slots slot on slot.id = sale.planogram_slot_id
    where sale.provider = 'IMA'
      and coalesce(slot.customer_price_czk, slot.dex_price_czk) = 0
      and sale.quantity > 0
      and sale.source_event_at >= timestamptz '2026-08-03 22:00:00+00'
      and sale.source_event_at <  timestamptz '2026-08-04 22:00:00+00'
      and (
        sale.free_vend_quantity <> sale.quantity
        or sale.cash_quantity <> 0
        or sale.cashless_quantity <> 0
        or sale.unknown_payment_quantity <> 0
        or sale.unpaid_dispense_quantity <> 0
      )
  ) then
    raise exception 'Zero-price IMA vend reclassification validation failed.';
  end if;
end $$;

commit;

select
  count(*) as free_sale_rows,
  coalesce(sum(free_vend_quantity), 0) as free_vend_quantity
from public.telemetry_sales_events
where provider = 'IMA'
  and free_vend_quantity > 0
  and source_event_at >= timestamptz '2026-08-03 22:00:00+00'
  and source_event_at <  timestamptz '2026-08-04 22:00:00+00';

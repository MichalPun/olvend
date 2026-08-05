-- A PA2 product-counter increment is authoritative evidence that the product
-- physically left the machine. Inventory depletion must therefore use the full
-- vend quantity and must not depend on when CA2/DA2 payment counters arrive.

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
        when lower(ri.unit) = lower(c.unit) then ri.quantity_per_vend * s.quantity
        when lower(ri.unit) = 'kg' and lower(c.unit) = 'g' then ri.quantity_per_vend * s.quantity * 1000
        when lower(ri.unit) = 'g' and lower(c.unit) = 'kg' then ri.quantity_per_vend * s.quantity / 1000
        when lower(ri.unit) = 'l' and lower(c.unit) = 'ml' then ri.quantity_per_vend * s.quantity * 1000
        when lower(ri.unit) = 'ml' and lower(c.unit) = 'l' then ri.quantity_per_vend * s.quantity / 1000
        else ri.quantity_per_vend * s.quantity end)::numeric, 3) as target_quantity
    from public.telemetry_sales_events s
    join public.machine_coffee_buttons b
      on b.machine_id = s.machine_id and b.active and b.selection_code = s.selection_code
    join public.machine_coffee_recipe_items ri
      on ri.machine_id = s.machine_id and ri.coffee_button_id = b.id and ri.active
    join public.machine_coffee_containers c
      on c.id = ri.coffee_container_id and c.machine_id = s.machine_id and c.active
    where s.id = any(p_sale_event_ids)
      and s.quantity > 0
      and ri.quantity_per_vend > 0
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
    set current_quantity = greatest(0, c.current_quantity - usage.quantity),
        updated_at = now()
    from usage
    where c.id = usage.coffee_container_id
    returning c.id
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

create or replace function public.apply_telemetry_stock_depletion(p_sale_event_ids bigint[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event record;
  v_balance record;
  v_needed numeric(14,3);
  v_moved numeric(14,3);
  v_requested numeric(14,3) := 0;
  v_applied numeric(14,3) := 0;
  v_rows integer := 0;
  v_events integer := 0;
begin
  -- Process events and their FEFO batches sequentially under row locks. Besides
  -- making the RPC idempotent, this prevents two events for the same product
  -- from both consuming the same pre-update balance in one bulk call.
  for v_event in
    select
      s.id as sale_event_id,
      sl.id as stock_location_id,
      p.id as product_id,
      greatest(0, s.quantity - coalesce(existing.quantity, 0))::numeric(14,3) as quantity
    from public.telemetry_sales_events s
    join lateral (
      select product.id
      from public.products product
      where product.sku = s.product_sku
      order by product.active desc, product.id
      limit 1
    ) p on true
    join public.stock_locations sl
      on sl.location_type = 'machine' and sl.machine_id = s.machine_id
    left join lateral (
      select sum(d.quantity) as quantity
      from public.telemetry_stock_depletions d
      where d.sale_event_id = s.id
        and d.product_id = p.id
    ) existing on true
    where s.id = any(p_sale_event_ids)
    order by s.source_event_at, s.id
  loop
    v_needed := v_event.quantity;
    v_requested := v_requested + v_needed;
    if v_needed <= 0 then
      continue;
    end if;

    v_events := v_events + 1;
    for v_balance in
      select
        balance.id,
        balance.batch_id,
        balance.quantity_on_hand
      from public.stock_location_balances balance
      left join public.inventory_batches batch on batch.id = balance.batch_id
      where balance.stock_location_id = v_event.stock_location_id
        and balance.product_id = v_event.product_id
        and balance.quantity_on_hand > 0
      order by
        coalesce(batch.use_by_date, batch.best_before_date, '9999-12-31'::date),
        balance.id
      for update of balance
    loop
      exit when v_needed <= 0;
      v_moved := least(v_needed, v_balance.quantity_on_hand);
      if v_moved <= 0 then
        continue;
      end if;

      update public.stock_location_balances
      set quantity_on_hand = quantity_on_hand - v_moved,
          updated_at = now()
      where id = v_balance.id;

      insert into public.telemetry_stock_depletions
        (sale_event_id, stock_location_id, product_id, batch_id, quantity)
      values (
        v_event.sale_event_id,
        v_event.stock_location_id,
        v_event.product_id,
        v_balance.batch_id,
        v_moved
      )
      on conflict (sale_event_id, product_id, batch_id) do update
        set quantity = public.telemetry_stock_depletions.quantity + excluded.quantity;

      insert into public.stock_movements_v13 (
        product_id,
        batch_id,
        from_stock_location_id,
        to_stock_location_id,
        movement_type,
        quantity_base_units,
        reference_type,
        reference_id,
        note
      ) values (
        v_event.product_id,
        v_balance.batch_id,
        v_event.stock_location_id,
        null,
        'sale',
        v_moved,
        'telemetry_sale',
        'telemetry-sale:' || v_event.sale_event_id,
        'Fyzický telemetrický výdej #' || v_event.sale_event_id || ' podle PA2'
      );

      v_needed := round((v_needed - v_moved)::numeric, 3);
      v_applied := v_applied + v_moved;
      v_rows := v_rows + 1;
    end loop;

  end loop;

  return jsonb_build_object(
    'inserted', v_rows,
    'sale_events', v_events,
    'requested_quantity', v_requested,
    'applied_quantity', v_applied,
    'unfulfilled_quantity', greatest(0, v_requested - v_applied)
  );
end $$;

revoke all on function public.apply_telemetry_stock_depletion(bigint[]) from public;
grant execute on function public.apply_telemetry_stock_depletion(bigint[]) to service_role;

comment on function public.apply_telemetry_stock_depletion(bigint[]) is
  'Idempotent FEFO stock depletion for the full physical PA2 vend quantity, independent of CA2/DA2 payment timing.';

comment on column public.telemetry_sales_events.unpaid_dispense_quantity is
  'Temporary or confirmed PA2 vend without a matched CA2/DA2 payment. The physical vend always reduces inventory; cases still unmatched after the reporting grace period are an internal control.';

commit;

-- Delayed CA2/DA2 counters are reconciled against pending PA2 vends on every
-- IMA ingest. Without this partial index PostgreSQL scanned the entire sales
-- history and the Edge Function repeatedly hit the statement timeout.

-- Supabase's linked SQL runner executes migration files in a transaction, so this
-- intentionally uses a regular CREATE INDEX. The partial predicate keeps the
-- indexed data set small and the one-time lock brief.
create index if not exists telemetry_sales_pending_reconcile_idx
  on public.telemetry_sales_events (
    provider,
    machine_id,
    source_event_at,
    id
  )
  where unpaid_dispense_quantity > 0;

comment on index public.telemetry_sales_pending_reconcile_idx is
  'Fast lookup of unresolved IMA vends for delayed DEX payment reconciliation.';

-- A physical PA2 vend can arrive after the machine's book balance has already
-- reached zero. Preserve the full vend audit trail without creating a negative
-- stock balance: record a balanced reconstruction-in and sale-out for the exact
-- shortfall. The depletion row makes the operation idempotent on every retry.
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
  v_shortfall numeric(14,3);
  v_requested numeric(14,3) := 0;
  v_applied numeric(14,3) := 0;
  v_reconstructed numeric(14,3) := 0;
  v_rows integer := 0;
  v_events integer := 0;
begin
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
    join lateral (
      select location.id
      from public.stock_locations location
      where location.location_type = 'machine'
        and location.machine_id = s.machine_id
      order by location.id
      limit 1
    ) sl on true
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
        product_id, batch_id, from_stock_location_id, to_stock_location_id,
        movement_type, quantity_base_units, reference_type, reference_id, note
      ) values (
        v_event.product_id, v_balance.batch_id, v_event.stock_location_id, null,
        'sale', v_moved, 'telemetry_sale',
        'telemetry-sale:' || v_event.sale_event_id,
        'Fyzický telemetrický výdej #' || v_event.sale_event_id || ' podle PA2'
      );

      v_needed := round((v_needed - v_moved)::numeric, 3);
      v_applied := v_applied + v_moved;
      v_rows := v_rows + 1;
    end loop;

    if v_needed > 0 then
      v_shortfall := v_needed;

      insert into public.stock_movements_v13 (
        product_id, batch_id, from_stock_location_id, to_stock_location_id,
        movement_type, quantity_base_units, reference_type, reference_id, note
      ) values (
        v_event.product_id, null, null, v_event.stock_location_id,
        'adjustment', v_shortfall, 'telemetry_stock_reconstruction',
        'telemetry-stock-reconstruction:' || v_event.sale_event_id,
        'Automatická rekonstrukce nulového stavu pro PA2 výdej #' || v_event.sale_event_id
      );

      insert into public.telemetry_stock_depletions
        (sale_event_id, stock_location_id, product_id, batch_id, quantity)
      values (
        v_event.sale_event_id,
        v_event.stock_location_id,
        v_event.product_id,
        null,
        v_shortfall
      )
      on conflict (sale_event_id, product_id, batch_id) do update
        set quantity = public.telemetry_stock_depletions.quantity + excluded.quantity;

      insert into public.stock_movements_v13 (
        product_id, batch_id, from_stock_location_id, to_stock_location_id,
        movement_type, quantity_base_units, reference_type, reference_id, note
      ) values (
        v_event.product_id, null, v_event.stock_location_id, null,
        'sale', v_shortfall, 'telemetry_sale_reconstruction',
        'telemetry-sale-reconstruction:' || v_event.sale_event_id,
        'Fyzický telemetrický výdej #' || v_event.sale_event_id || ' podle PA2 · rekonstruovaný nulový stav'
      );

      v_needed := 0;
      v_applied := v_applied + v_shortfall;
      v_reconstructed := v_reconstructed + v_shortfall;
      v_rows := v_rows + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'inserted', v_rows,
    'sale_events', v_events,
    'requested_quantity', v_requested,
    'applied_quantity', v_applied,
    'reconstructed_quantity', v_reconstructed,
    'unfulfilled_quantity', greatest(0, v_requested - v_applied)
  );
end $$;

revoke all on function public.apply_telemetry_stock_depletion(bigint[]) from public;
grant execute on function public.apply_telemetry_stock_depletion(bigint[]) to service_role;

comment on function public.apply_telemetry_stock_depletion(bigint[]) is
  'Idempotent FEFO stock depletion for every physical PA2 vend; zero-balance shortfalls are auditably reconstructed without negative stock.';

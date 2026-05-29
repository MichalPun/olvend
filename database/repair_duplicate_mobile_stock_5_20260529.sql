do $$
declare
  v_result jsonb;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'duplicate_mobile_repair'
      and reference_id = 'repair-mobile-stock-5-20260529'
  ) then
    raise notice 'repair already applied';
    return;
  end if;

  with excess as (
    with movement_totals as (
      select
        reference_id,
        product_id,
        from_stock_location_id,
        to_stock_location_id,
        sum(quantity_base_units) as moved_qty
      from public.stock_movements_v13
      where reference_type = 'mobile_stock_request'
        and reference_id = 'mobile-stock:5'
      group by reference_id, product_id, from_stock_location_id, to_stock_location_id
    ),
    item_totals as (
      select
        'mobile-stock:' || r.id as reference_id,
        i.product_id,
        sum(coalesce(i.confirmed_quantity, i.prepared_quantity, i.requested_quantity, 0)) as item_qty
      from public.mobile_stock_requests r
      join public.mobile_stock_request_items i on i.request_id = r.id
      where r.id = 5
      group by r.id, i.product_id
    )
    select
      mt.product_id,
      mt.from_stock_location_id,
      mt.to_stock_location_id,
      round((mt.moved_qty - it.item_qty)::numeric, 3) as excess_qty
    from movement_totals mt
    join item_totals it on it.reference_id = mt.reference_id and it.product_id = mt.product_id
    where mt.moved_qty > it.item_qty
  ),
  repair_rows as (
    select jsonb_agg(jsonb_build_object(
      'product_id', e.product_id,
      'batch_id', null,
      'from_stock_location_id', e.to_stock_location_id,
      'to_stock_location_id', e.from_stock_location_id,
      'movement_type', 'return',
      'quantity_base_units', e.excess_qty,
      'unit_price', null,
      'reference_type', 'duplicate_mobile_repair',
      'reference_id', 'repair-mobile-stock-5-20260529',
      'note', 'Oprava duplicitního propsání mobilního dokladu #5'
    )) as rows
    from excess e
    join public.stock_location_balances b
      on b.stock_location_id = e.to_stock_location_id
      and b.product_id = e.product_id
      and b.batch_id is null
    where coalesce(b.quantity_on_hand, 0) >= e.excess_qty
  )
  select public.apply_stock_movements_v13(coalesce(rows, '[]'::jsonb))
  into v_result
  from repair_rows;

  raise notice 'repair result %', v_result;
end $$;

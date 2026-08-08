begin;

alter table public.inventory_batches
  add column if not exists storage_bin_code text;

create index if not exists inventory_batches_storage_bin_idx
  on public.inventory_batches (storage_bin_code)
  where storage_bin_code is not null;

create or replace function public.assign_purchase_receipt_expiries_v31(
  p_purchase_order_id bigint,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.purchase_orders%rowtype;
  v_supplier_name text;
  v_item record;
  v_line jsonb;
  v_allocation jsonb;
  v_location_id bigint;
  v_source_quantity numeric(14,3);
  v_allocated_quantity numeric(14,3);
  v_quantity numeric(14,3);
  v_expiry_date date;
  v_storage_bin_code text;
  v_batch_id bigint;
  v_balance record;
  v_assignable_quantity numeric(14,3);
  v_issued_quantity numeric(14,3);
  v_batch_balance_quantity numeric(14,3);
  v_unit_price numeric(12,4);
  v_created_batches integer := 0;
  v_total_already_issued numeric(14,3) := 0;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'Položky expirací musí být pole.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('purchase-receipt-expiry:' || p_purchase_order_id::text, 0));

  select * into v_order
  from public.purchase_orders
  where id = p_purchase_order_id
  for update;

  if not found or v_order.status <> 'received' then
    raise exception 'Doklad není přijatý nebo neexistuje.';
  end if;

  select name into v_supplier_name
  from public.purchase_suppliers
  where id = v_order.supplier_id;

  for v_item in
    select
      poi.product_id,
      sum(poi.received_quantity) as received_quantity,
      p.name as product_name,
      p.expiry_tracking_mode
    from public.purchase_order_items poi
    join public.products p on p.id = poi.product_id
    where poi.purchase_order_id = p_purchase_order_id
      and poi.received_quantity > 0
      and p.expiry_tracking_mode <> 'none'
    group by poi.product_id, p.name, p.expiry_tracking_mode
    order by p.name
  loop
    v_line := null;
    select value into v_line
    from jsonb_array_elements(p_lines)
    where nullif(value->>'product_id', '')::bigint = v_item.product_id
    limit 1;

    if v_line is null or jsonb_typeof(v_line->'allocations') <> 'array'
       or jsonb_array_length(v_line->'allocations') = 0 then
      raise exception 'U položky % chybí rozdělení expirací.', v_item.product_name;
    end if;

    if exists (
      select 1 from public.stock_movements_v13
      where reference_type = 'purchase_order'
        and reference_id = p_purchase_order_id::text
        and movement_type = 'receipt'
        and product_id = v_item.product_id
        and batch_id is not null
    ) then
      raise exception 'Položka % už je do expirací zařazená.', v_item.product_name;
    end if;

    select
      min(to_stock_location_id),
      sum(quantity_base_units),
      max(unit_price)
    into v_location_id, v_source_quantity, v_unit_price
    from public.stock_movements_v13
    where reference_type = 'purchase_order'
      and reference_id = p_purchase_order_id::text
      and movement_type = 'receipt'
      and product_id = v_item.product_id
      and batch_id is null;

    if v_location_id is null or abs(coalesce(v_source_quantity, 0) - v_item.received_quantity) > 0.0001 then
      raise exception 'Položku % nelze bezpečně svázat s původním příjmem.', v_item.product_name;
    end if;

    select coalesce(sum(nullif(value->>'quantity', '')::numeric), 0)
      into v_allocated_quantity
    from jsonb_array_elements(v_line->'allocations');

    if abs(v_allocated_quantity - v_item.received_quantity) > 0.0001 then
      raise exception 'U položky % je přijato % ks, ale k expiracím je rozděleno % ks.',
        v_item.product_name, v_item.received_quantity, v_allocated_quantity;
    end if;

    for v_allocation in select value from jsonb_array_elements(v_line->'allocations')
    loop
      v_quantity := nullif(v_allocation->>'quantity', '')::numeric;
      v_expiry_date := nullif(v_allocation->>'expiry_date', '')::date;
      v_storage_bin_code := nullif(btrim(v_allocation->>'storage_bin_code'), '');
      if v_quantity is null or v_quantity <= 0 or v_expiry_date is null or v_storage_bin_code is null then
        raise exception 'U položky % doplň u každého řádku množství, expiraci a regál.', v_item.product_name;
      end if;
    end loop;

    select id, quantity_on_hand into v_balance
    from public.stock_location_balances
    where stock_location_id = v_location_id
      and product_id = v_item.product_id
      and batch_id is null
    order by id
    limit 1
    for update;

    v_assignable_quantity := least(coalesce(v_balance.quantity_on_hand, 0), v_source_quantity);
    v_issued_quantity := greatest(v_source_quantity - v_assignable_quantity, 0);
    v_total_already_issued := v_total_already_issued + v_issued_quantity;

    if v_balance.id is not null and v_assignable_quantity > 0 then
      update public.stock_location_balances
      set quantity_on_hand = round((quantity_on_hand - v_assignable_quantity)::numeric, 3), updated_at = now()
      where id = v_balance.id;
    end if;

    delete from public.stock_movements_v13
    where reference_type = 'purchase_order'
      and reference_id = p_purchase_order_id::text
      and movement_type = 'receipt'
      and product_id = v_item.product_id
      and batch_id is null;

    for v_allocation in
      select value
      from jsonb_array_elements(v_line->'allocations')
      order by (value->>'expiry_date')::date, (value->>'storage_bin_code')
    loop
      v_quantity := (v_allocation->>'quantity')::numeric;
      v_expiry_date := (v_allocation->>'expiry_date')::date;
      v_storage_bin_code := upper(btrim(v_allocation->>'storage_bin_code'));
      v_batch_balance_quantity := greatest(v_quantity - least(v_issued_quantity, v_quantity), 0);
      v_issued_quantity := greatest(v_issued_quantity - v_quantity, 0);

      insert into public.inventory_batches (
        product_id, best_before_date, use_by_date, received_at, supplier_name,
        storage_bin_code, note
      ) values (
        v_item.product_id,
        case when v_item.expiry_tracking_mode = 'best_before' then v_expiry_date end,
        case when v_item.expiry_tracking_mode = 'use_by' then v_expiry_date end,
        coalesce(v_order.received_at, now()),
        v_supplier_name,
        v_storage_bin_code,
        'Zařazeno z přijatého dokladu #' || p_purchase_order_id
      ) returning id into v_batch_id;

      if v_batch_balance_quantity > 0 then
        insert into public.stock_location_balances (
          stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
        ) values (
          v_location_id, v_item.product_id, v_batch_id, round(v_batch_balance_quantity::numeric, 3), 0, now()
        );
      end if;

      insert into public.stock_movements_v13 (
        product_id, batch_id, to_stock_location_id, movement_type,
        quantity_base_units, unit_price, reference_type, reference_id, note
      ) values (
        v_item.product_id, v_batch_id, v_location_id, 'receipt',
        round(v_quantity::numeric, 3), v_unit_price, 'purchase_order', p_purchase_order_id::text,
        'Příjem zařazen do regálu ' || v_storage_bin_code || ' s expirací ' || v_expiry_date::text
      );
      v_created_batches := v_created_batches + 1;
    end loop;
  end loop;

  return jsonb_build_object(
    'purchase_order_id', p_purchase_order_id,
    'created_batches', v_created_batches,
    'already_issued_quantity', v_total_already_issued,
    'status', 'assigned'
  );
end
$$;

grant execute on function public.assign_purchase_receipt_expiries_v31(bigint, jsonb) to anon, authenticated;

commit;

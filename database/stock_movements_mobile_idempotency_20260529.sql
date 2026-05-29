create or replace function public.apply_stock_movements_v13(movement_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  movement_row jsonb;
  v_product_id bigint;
  v_batch_id bigint;
  v_from_location_id bigint;
  v_to_location_id bigint;
  v_movement_type text;
  v_quantity numeric(12,3);
  v_unit_price numeric(12,2);
  v_reference_type text;
  v_reference_id text;
  v_note text;
  v_allow_negative_source boolean;
  v_existing_mobile_reference_id text;
  v_guard_reference record;
  source_balance record;
  target_balance record;
  inserted_count integer := 0;
begin
  if movement_rows is null or jsonb_typeof(movement_rows) <> 'array' then
    raise exception 'movement_rows must be a JSON array';
  end if;

  for v_guard_reference in
    select distinct nullif(value->>'reference_id', '') as reference_id
    from jsonb_array_elements(movement_rows)
    where nullif(value->>'reference_type', '') = 'mobile_stock_request'
      and nullif(value->>'reference_id', '') is not null
  loop
    perform pg_advisory_xact_lock(hashtextextended('stock_movements_v13:mobile_stock_request:' || v_guard_reference.reference_id, 0));
  end loop;

  select sm.reference_id
  into v_existing_mobile_reference_id
  from public.stock_movements_v13 sm
  join (
    select distinct nullif(value->>'reference_id', '') as reference_id
    from jsonb_array_elements(movement_rows)
    where nullif(value->>'reference_type', '') = 'mobile_stock_request'
      and nullif(value->>'reference_id', '') is not null
  ) incoming on incoming.reference_id = sm.reference_id
  where sm.reference_type = 'mobile_stock_request'
  limit 1;

  if v_existing_mobile_reference_id is not null then
    return jsonb_build_object(
      'inserted', 0,
      'skipped_existing_reference_type', 'mobile_stock_request',
      'skipped_existing_reference_id', v_existing_mobile_reference_id
    );
  end if;

  for movement_row in
    select value from jsonb_array_elements(movement_rows)
  loop
    v_product_id := nullif(movement_row->>'product_id', '')::bigint;
    v_batch_id := nullif(movement_row->>'batch_id', '')::bigint;
    v_from_location_id := nullif(movement_row->>'from_stock_location_id', '')::bigint;
    v_to_location_id := nullif(movement_row->>'to_stock_location_id', '')::bigint;
    v_movement_type := nullif(movement_row->>'movement_type', '');
    v_quantity := nullif(movement_row->>'quantity_base_units', '')::numeric;
    v_unit_price := nullif(movement_row->>'unit_price', '')::numeric;
    v_reference_type := nullif(movement_row->>'reference_type', '');
    v_reference_id := nullif(movement_row->>'reference_id', '');
    v_note := nullif(movement_row->>'note', '');

    if v_product_id is null then
      raise exception 'Movement is missing product_id';
    end if;
    if v_movement_type is null then
      raise exception 'Movement for product % is missing movement_type', v_product_id;
    end if;
    if v_quantity is null or v_quantity <= 0 then
      raise exception 'Movement for product % has invalid quantity %', v_product_id, v_quantity;
    end if;

    v_allow_negative_source := false;
    if v_from_location_id is not null then
      select exists (
        select 1
        from public.products p
        where p.id = v_product_id
          and p.product_category = 'food_ready'
          and v_movement_type = 'load_vehicle'
          and v_reference_type in ('mobile_stock_request', 'loading_session')
      )
      into v_allow_negative_source;

      select id, quantity_on_hand
      into source_balance
      from public.stock_location_balances
      where stock_location_id = v_from_location_id
        and product_id = v_product_id
        and batch_id is not distinct from v_batch_id
      order by id
      limit 1
      for update;

      if not v_allow_negative_source and (source_balance.id is null or coalesce(source_balance.quantity_on_hand, 0) + 0.0001 < v_quantity) then
        raise exception 'Insufficient stock for product % at stock location %', v_product_id, v_from_location_id;
      end if;

      if source_balance.id is not null then
        update public.stock_location_balances
        set
          quantity_on_hand = round((coalesce(quantity_on_hand, 0) - v_quantity)::numeric, 3),
          updated_at = now()
        where id = source_balance.id;
      else
        insert into public.stock_location_balances (
          stock_location_id,
          product_id,
          batch_id,
          quantity_on_hand,
          reserved_quantity,
          updated_at
        ) values (
          v_from_location_id,
          v_product_id,
          v_batch_id,
          round((-v_quantity)::numeric, 3),
          0,
          now()
        );
      end if;
    end if;

    if v_to_location_id is not null then
      select id, quantity_on_hand
      into target_balance
      from public.stock_location_balances
      where stock_location_id = v_to_location_id
        and product_id = v_product_id
        and batch_id is not distinct from v_batch_id
      order by id
      limit 1
      for update;

      if target_balance.id is not null then
        update public.stock_location_balances
        set
          quantity_on_hand = round((coalesce(quantity_on_hand, 0) + v_quantity)::numeric, 3),
          updated_at = now()
        where id = target_balance.id;
      else
        insert into public.stock_location_balances (
          stock_location_id,
          product_id,
          batch_id,
          quantity_on_hand,
          reserved_quantity,
          updated_at
        ) values (
          v_to_location_id,
          v_product_id,
          v_batch_id,
          v_quantity,
          0,
          now()
        );
      end if;
    end if;

    insert into public.stock_movements_v13 (
      product_id,
      batch_id,
      from_stock_location_id,
      to_stock_location_id,
      movement_type,
      quantity_base_units,
      unit_price,
      reference_type,
      reference_id,
      note
    ) values (
      v_product_id,
      v_batch_id,
      v_from_location_id,
      v_to_location_id,
      v_movement_type,
      v_quantity,
      v_unit_price,
      v_reference_type,
      v_reference_id,
      v_note
    );

    inserted_count := inserted_count + 1;
  end loop;

  return jsonb_build_object('inserted', inserted_count);
end;
$$;

grant execute on function public.apply_stock_movements_v13(jsonb) to anon, authenticated;

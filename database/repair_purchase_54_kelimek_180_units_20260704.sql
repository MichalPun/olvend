do $$
declare
  v_purchase_order_id bigint := 54;
  v_purchase_item_id bigint := 524;
  v_product_id bigint := 78;
  v_stock_location_id bigint := 1;
  v_movement_id bigint := 14516;
  v_old_quantity numeric := 640;
  v_new_quantity numeric := 32000;
  v_total_net numeric := 12416;
  v_unit_cost numeric := v_total_net / v_new_quantity;
begin
  if not exists (
    select 1
    from public.purchase_order_items
    where id = v_purchase_item_id
      and purchase_order_id = v_purchase_order_id
      and product_id = v_product_id
      and received_quantity = v_old_quantity
  ) then
    raise exception 'Expected purchase item % for product % with quantity % was not found.', v_purchase_item_id, v_product_id, v_old_quantity;
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and reference_type = 'purchase_order'
      and reference_id = v_purchase_order_id::text
      and product_id = v_product_id
      and quantity_base_units = v_old_quantity
      and to_stock_location_id = v_stock_location_id
  ) then
    raise exception 'Expected receipt movement % for purchase order % was not found.', v_movement_id, v_purchase_order_id;
  end if;

  update public.purchase_order_items
  set ordered_quantity = v_new_quantity,
      received_quantity = v_new_quantity,
      unit_cost = v_unit_cost,
      note = concat_ws(
        E'\n',
        '[dph:21][celkem-bez-dph:12416.00][celkem-s-dph:15023.36][mena:CZK][kurz:1][doklad-bez-dph:12416.00][doklad-celkem:15023.36]',
        'Kelímek 180 ml · SKU 45 · přepočet 640 tyčí × 50 ks = 32 000 ks · jednotka faktury tyč'
      )
  where id = v_purchase_item_id;

  update public.stock_movements_v13
  set quantity_base_units = v_new_quantity,
      unit_price = v_unit_cost,
      note = concat_ws(
        ' ',
        note,
        '[oprava: 640 tyčí × 50 ks = 32 000 ks]'
      )
  where id = v_movement_id;

  update public.stock_location_balances
  set quantity_on_hand = quantity_on_hand + (v_new_quantity - v_old_quantity),
      updated_at = now()
  where stock_location_id = v_stock_location_id
    and product_id = v_product_id
    and batch_id is null;

  if not found then
    insert into public.stock_location_balances (
      stock_location_id,
      product_id,
      batch_id,
      quantity_on_hand,
      reserved_quantity,
      updated_at
    ) values (
      v_stock_location_id,
      v_product_id,
      null,
      v_new_quantity,
      0,
      now()
    );
  end if;
end $$;

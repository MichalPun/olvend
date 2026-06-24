do $$
declare
  v_purchase_order_id bigint := 44;
  v_product_id bigint := 104;
  v_quantity numeric := 630;
  v_unit_price numeric := 86;
  v_automaty_location_id bigint := 5;
  v_blucina_location_id bigint := 1;
  v_existing_correction bigint;
begin
  select id
    into v_existing_correction
  from public.stock_movements_v13
  where reference_type = 'purchase_order_correction'
    and reference_id = v_purchase_order_id::text
    and product_id = v_product_id
    and from_stock_location_id = v_automaty_location_id
    and to_stock_location_id = v_blucina_location_id
  limit 1;

  if v_existing_correction is not null then
    return;
  end if;

  update public.stock_location_balances
  set quantity_on_hand = quantity_on_hand - v_quantity,
      updated_at = now()
  where stock_location_id = v_automaty_location_id
    and product_id = v_product_id
    and batch_id is null;

  insert into public.stock_location_balances (
    stock_location_id,
    product_id,
    batch_id,
    quantity_on_hand,
    reserved_quantity
  )
  values (
    v_blucina_location_id,
    v_product_id,
    null,
    v_quantity,
    0
  )
  on conflict (stock_location_id, product_id, batch_id)
  do update
  set quantity_on_hand = public.stock_location_balances.quantity_on_hand + excluded.quantity_on_hand,
      updated_at = now();

  insert into public.stock_movements_v13 (
    product_id,
    from_stock_location_id,
    to_stock_location_id,
    movement_type,
    quantity_base_units,
    unit_price,
    reference_type,
    reference_id,
    note
  )
  values (
    v_product_id,
    v_automaty_location_id,
    v_blucina_location_id,
    'transfer',
    v_quantity,
    v_unit_price,
    'purchase_order_correction',
    v_purchase_order_id::text,
    'Oprava chybného příjmu faktury 26161241: naskladněno na Automaty, správně BLUČINA.'
  );

  update public.purchase_orders
  set received_stock_location_id = v_blucina_location_id,
      note = concat_ws(' · ', nullif(note, ''), 'Oprava skladu příjmu: Automaty -> BLUČINA')
  where id = v_purchase_order_id;
end $$;

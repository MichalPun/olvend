-- Dorovnani evidence Sophia na BLUCINA na 0 kg.
-- Fyzicky na sklade neni nic; po inventure 2026-07-15 a naslednych pohybech
-- zustala evidence v minusu -9,5 kg. Toto je evidencni korekce, ne prijem zbozi.

do $$
declare
  v_product_id bigint := 108;
  v_location_id bigint := 1;
  v_balance_id bigint := 46;
  v_reference_id text := 'repair-blucina-sophia-zero-balance-20260721';
  v_current_quantity numeric(12,3);
  v_adjustment_quantity numeric(12,3);
  v_existing_movement_id bigint;
begin
  select id
  into v_existing_movement_id
  from public.stock_movements_v13
  where reference_type = 'data_repair'
    and reference_id = v_reference_id
    and product_id = v_product_id
    and to_stock_location_id = v_location_id
  limit 1;

  if v_existing_movement_id is not null then
    return;
  end if;

  select quantity_on_hand
  into v_current_quantity
  from public.stock_location_balances
  where id = v_balance_id
    and stock_location_id = v_location_id
    and product_id = v_product_id
    and batch_id is null
  for update;

  if v_current_quantity is null then
    raise exception 'Expected BLUCINA Sophia balance % was not found.', v_balance_id;
  end if;

  if v_current_quantity >= 0 then
    raise exception 'BLUCINA Sophia balance is %, expected a negative quantity before repair.', v_current_quantity;
  end if;

  v_adjustment_quantity := abs(v_current_quantity);

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
  )
  values (
    v_product_id,
    null,
    null,
    v_location_id,
    'adjustment',
    v_adjustment_quantity,
    'data_repair',
    v_reference_id,
    concat('2026-07-21 · dorovnani Sophia BLUCINA na 0 kg podle fyzicke kontroly · puvodni stav ', v_current_quantity, ' kg')
  );

  update public.stock_location_balances
  set quantity_on_hand = 0,
      updated_at = now()
  where id = v_balance_id
    and stock_location_id = v_location_id
    and product_id = v_product_id
    and batch_id is null;
end $$;

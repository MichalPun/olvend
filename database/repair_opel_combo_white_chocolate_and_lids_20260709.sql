do $$
declare
  v_delta numeric := 9;
  v_opel_combo_location_id bigint := 6;
  v_fiat_location_id bigint := 4;
  v_automaty_location_id bigint := 5;
  v_white_chocolate_product_id bigint := 105;
  v_lid_item_id bigint := 1486;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where id = 13420
      and product_id = v_white_chocolate_product_id
      and from_stock_location_id = v_opel_combo_location_id
      and to_stock_location_id = v_automaty_location_id
      and quantity_base_units = 10
  ) then
    update public.stock_movements_v13
    set
      quantity_base_units = 1,
      note = '2026-06-30 · převod do automatů · Filled Products · Sandra Svobodová · Ingredient · oprava: 1 kg, ne 1 karton / 10 kg'
    where id = 13420;

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand + v_delta)::numeric, 3), updated_at = now()
    where stock_location_id = v_opel_combo_location_id
      and product_id = v_white_chocolate_product_id
      and batch_id is null;

    if not found then
      insert into public.stock_location_balances (stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity)
      values (v_opel_combo_location_id, v_white_chocolate_product_id, null, v_delta, 0);
    end if;

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand - v_delta)::numeric, 3), updated_at = now()
    where stock_location_id = v_automaty_location_id
      and product_id = v_white_chocolate_product_id
      and batch_id is null;

    insert into public.stock_movements_v13 (
      product_id,
      from_stock_location_id,
      to_stock_location_id,
      movement_type,
      quantity_base_units,
      reference_type,
      reference_id,
      note
    )
    values (
      v_white_chocolate_product_id,
      v_opel_combo_location_id,
      v_fiat_location_id,
      'transfer',
      4,
      'manual_repair',
      'repair-opel-combo-white-chocolate-20260709',
      'Oprava reálného předání 4 kg bílé čokolády z Opel Combo 7Z71808 na Fiat Doblo 5AP9000 / Kristýna Dvořáková.'
    );

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand - 4)::numeric, 3), updated_at = now()
    where stock_location_id = v_opel_combo_location_id
      and product_id = v_white_chocolate_product_id
      and batch_id is null;

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand + 4)::numeric, 3), updated_at = now()
    where stock_location_id = v_fiat_location_id
      and product_id = v_white_chocolate_product_id
      and batch_id is null;

    if not found then
      insert into public.stock_location_balances (stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity)
      values (v_fiat_location_id, v_white_chocolate_product_id, null, 4, 0);
    end if;
  end if;

  update public.mobile_stock_request_items
  set
    unit = 'ks',
    requested_quantity = 10,
    prepared_quantity = 10,
    note = 'oprava: víčka v nakládce vedena jako 10 ks, ne 10 × 1 tyč'
  where id = v_lid_item_id
    and product_id = 136
    and unit = '1 tyč'
    and requested_quantity = 10;
end $$;

select
  sl.name as stock_location,
  b.quantity_on_hand
from public.stock_location_balances b
join public.stock_locations sl on sl.id = b.stock_location_id
where b.product_id = 105
  and b.stock_location_id in (4, 5, 6)
order by b.stock_location_id;

select
  id,
  product_id,
  requested_quantity,
  prepared_quantity,
  unit,
  note
from public.mobile_stock_request_items
where id = 1486;

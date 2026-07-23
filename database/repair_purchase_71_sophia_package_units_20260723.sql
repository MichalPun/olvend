-- Oprava prijmu Sophia v dokladu 71.
-- Zadano bylo 10 beden po 10 x 0,5 kg = 50 kg.
-- Kvuli chybnemu zobrazeni/prepoctu se ulozilo 5000 kg a 0,42 Kc/kg.

do $$
declare
  v_purchase_order_id bigint := 71;
  v_item_id bigint := 691;
  v_movement_id bigint := 20179;
  v_balance_id bigint := 46;
  v_product_id bigint := 108;
  v_location_id bigint := 1;
  v_reference_id text := 'repair-purchase-71-sophia-package-units-20260723';
  v_old_quantity numeric(12,3) := 5000.000;
  v_new_quantity numeric(12,3) := 50.000;
  v_old_unit_cost numeric(12,4) := 0.4200;
  v_new_unit_cost numeric(12,4) := 42.0000;
  v_delta numeric(12,3);
begin
  if exists (
    select 1
    from public.purchase_order_items
    where id = v_item_id
      and purchase_order_id = v_purchase_order_id
      and product_id = v_product_id
      and ordered_quantity = v_new_quantity
      and received_quantity = v_new_quantity
      and unit_cost = v_new_unit_cost
  ) then
    return;
  end if;

  if not exists (
    select 1
    from public.purchase_order_items
    where id = v_item_id
      and purchase_order_id = v_purchase_order_id
      and product_id = v_product_id
      and ordered_quantity = v_old_quantity
      and received_quantity = v_old_quantity
      and unit_cost = v_old_unit_cost
  ) then
    raise exception 'Expected purchase_order_items row % for purchase order % was not found in original state.', v_item_id, v_purchase_order_id;
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and product_id = v_product_id
      and to_stock_location_id = v_location_id
      and movement_type = 'receipt'
      and quantity_base_units = v_old_quantity
      and unit_price = v_old_unit_cost
      and reference_type = 'purchase_order'
      and reference_id = v_purchase_order_id::text
  ) then
    raise exception 'Expected stock movement % for purchase order % was not found in original state.', v_movement_id, v_purchase_order_id;
  end if;

  v_delta := v_old_quantity - v_new_quantity;

  update public.purchase_order_items
  set ordered_quantity = v_new_quantity,
      received_quantity = v_new_quantity,
      unit_cost = v_new_unit_cost,
      note = E'[dph:21][celkem-bez-dph:2100.00][celkem-s-dph:2541.00][mena:CZK][kurz:1][doklad-bez-dph:2100.00][doklad-celkem:2541.00]\n'
        || 'oVe FD COFFEE SOPHIA 500g · SKU 44 · jednotka faktury ks · prepočet 10 beden x 10 baleni x 0,5 kg = 50 kg · skladova cena 42,00 Kc/kg'
        || E'\nOprava 23. 7. 2026: puvodne ulozeno 5000 kg a 0,42 Kc/kg.'
  where id = v_item_id;

  update public.stock_movements_v13
  set quantity_base_units = v_new_quantity,
      unit_price = v_new_unit_cost,
      note = concat_ws(
        ' · ',
        nullif(note, ''),
        'Oprava 23. 7. 2026: Sophia doklad 71 byl 10 beden po 10 x 0,5 kg = 50 kg; puvodne prijato 5000 kg.'
      )
  where id = v_movement_id;

  update public.stock_location_balances
  set quantity_on_hand = round((coalesce(quantity_on_hand, 0) - v_delta)::numeric, 3),
      updated_at = now()
  where id = v_balance_id
    and stock_location_id = v_location_id
    and product_id = v_product_id
    and batch_id is null;

  if not found then
    raise exception 'Expected BLUCINA Sophia balance % was not found.', v_balance_id;
  end if;
end $$;

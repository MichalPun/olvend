-- Oprava ceny prijmu Sophia v dokladu 71.
-- Prijato bylo 10 beden x 10 baleni x 0,5 kg = 50 kg.
-- Cena je 210 Kc za 0,5kg baleni, tedy 420 Kc/kg a celkem 21 000 Kc bez DPH.

do $$
declare
  v_purchase_order_id bigint := 71;
  v_item_id bigint := 691;
  v_movement_id bigint := 20179;
  v_product_id bigint := 108;
  v_quantity numeric(12,3) := 50.000;
  v_old_unit_cost numeric(12,4) := 42.0000;
  v_new_unit_cost numeric(12,4) := 420.0000;
begin
  if exists (
    select 1
    from public.purchase_order_items
    where id = v_item_id
      and purchase_order_id = v_purchase_order_id
      and product_id = v_product_id
      and ordered_quantity = v_quantity
      and received_quantity = v_quantity
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
      and ordered_quantity = v_quantity
      and received_quantity = v_quantity
      and unit_cost = v_old_unit_cost
  ) then
    raise exception 'Expected purchase_order_items row % for purchase order % was not found in original price state.', v_item_id, v_purchase_order_id;
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and product_id = v_product_id
      and movement_type = 'receipt'
      and quantity_base_units = v_quantity
      and unit_price = v_old_unit_cost
      and reference_type = 'purchase_order'
      and reference_id = v_purchase_order_id::text
  ) then
    raise exception 'Expected stock movement % for purchase order % was not found in original price state.', v_movement_id, v_purchase_order_id;
  end if;

  update public.purchase_order_items
  set unit_cost = v_new_unit_cost,
      note = E'[dph:21][celkem-bez-dph:21000.00][celkem-s-dph:25410.00][mena:CZK][kurz:1][doklad-bez-dph:21000.00][doklad-celkem:25410.00]\n'
        || 'oVe FD COFFEE SOPHIA 500g · SKU 44 · jednotka faktury ks · prepocet 10 beden x 10 baleni x 0,5 kg = 50 kg · cena 210 Kc / 0,5 kg · skladova cena 420,00 Kc/kg'
        || E'\nOprava 23. 7. 2026: mnozstvi 50 kg zustava, puvodne po oprave ceny ulozeno 42 Kc/kg.'
  where id = v_item_id;

  update public.stock_movements_v13
  set unit_price = v_new_unit_cost,
      note = concat_ws(
        ' · ',
        nullif(note, ''),
        'Oprava 23. 7. 2026: cena Sophia doklad 71 je 210 Kc / 0,5 kg = 420 Kc/kg; puvodne po oprave ulozeno 42 Kc/kg.'
      )
  where id = v_movement_id;
end $$;

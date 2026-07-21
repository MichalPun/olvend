-- Oprava skladoveho odectu FV26-0165 pro Sophia.
-- Faktura obsahovala 10 ks baleni po 0,5 kg = 5 kg.
-- Skladovy pohyb byl omylem zapsany jako 10 kg, proto vracime rozdil 5 kg na BLUCINA.

do $$
declare
  v_movement_id bigint := 18615;
  v_balance_id bigint := 46;
  v_product_id bigint := 108;
  v_location_id bigint := 1;
  v_old_quantity numeric(12,3);
  v_new_quantity numeric(12,3) := 5.000;
  v_delta numeric(12,3);
begin
  select quantity_base_units
  into v_old_quantity
  from public.stock_movements_v13
  where id = v_movement_id
    and product_id = v_product_id
    and from_stock_location_id = v_location_id
    and movement_type = 'sale'
    and reference_type = 'sales_document'
    and reference_id = 'sales-document:FV26-0165:1784533662070'
  for update;

  if v_old_quantity is null then
    raise exception 'Expected FV26-0165 Sophia movement % was not found.', v_movement_id;
  end if;

  if v_old_quantity <> 10.000 then
    raise exception 'Unexpected FV26-0165 Sophia movement quantity: %, expected 10.000 before repair.', v_old_quantity;
  end if;

  v_delta := v_old_quantity - v_new_quantity;

  update public.stock_movements_v13
  set quantity_base_units = v_new_quantity,
      note = concat_ws(
        ' · ',
        nullif(note, ''),
        'Oprava 21. 7. 2026: FV26-0165 bylo 10 ks baleni po 0,5 kg = 5 kg; puvodne odecteno 10 kg.'
      )
  where id = v_movement_id;

  update public.stock_location_balances
  set quantity_on_hand = round((coalesce(quantity_on_hand, 0) + v_delta)::numeric, 3),
      updated_at = now()
  where id = v_balance_id
    and stock_location_id = v_location_id
    and product_id = v_product_id
    and batch_id is null;

  if not found then
    raise exception 'Expected BLUCINA Sophia balance % was not found.', v_balance_id;
  end if;
end $$;

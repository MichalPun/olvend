-- Chybějící fyzická nakládka Nestea Peach (SKU 67) do Renaultu 2TX7928 dne 1. 8. 2026.
-- Operátor potvrdil fyzicky naložených 12 ks. Následně byl 1 ks vložen do RIGUMu
-- v návštěvě #70, takže správný zůstatek vozidla je 11 ks.
-- FEFO: 8 ks šarže 261 (20. 2. 2027) + 4 ks šarže 262 (30. 3. 2027).

do $$
declare
  v_reference_prefix constant text := 'repair-renault-nestea-peach-load-20260801';
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id like v_reference_prefix || '-%'
  ) then
    return;
  end if;

  if coalesce((
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 1 and product_id = 99 and batch_id = 261
  ), 0) < 8 then
    raise exception 'Nestačí šarže 261 Nestea Peach ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 1 and product_id = 99 and batch_id = 262
  ), 0) < 4 then
    raise exception 'Nestačí šarže 262 Nestea Peach ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 2 and product_id = 99 and batch_id is null
  ), 0) <> -1 then
    raise exception 'Neočekávaný výchozí nešaržový stav Nestea Peach v Renaultu.';
  end if;

  if coalesce((
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 31 and product_id = 99 and batch_id is null
  ), 0) < 1 then
    raise exception 'V RIGUMu chybí 1 ks Nestea Peach k přeřazení na šarži.';
  end if;

  perform public.apply_stock_movements_v13(
    jsonb_build_array(
      jsonb_build_object(
        'product_id', 99,
        'batch_id', 261,
        'from_stock_location_id', 1,
        'to_stock_location_id', 2,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 8,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-batch-261',
        'note', 'Potvrzená fyzická nakládka 12 ks Nestea Peach · Renault 2TX7928 · FEFO část 8 ks'
      ),
      jsonb_build_object(
        'product_id', 99,
        'batch_id', 262,
        'from_stock_location_id', 1,
        'to_stock_location_id', 2,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 4,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-batch-262',
        'note', 'Potvrzená fyzická nakládka 12 ks Nestea Peach · Renault 2TX7928 · FEFO část 4 ks'
      ),
      jsonb_build_object(
        'product_id', 99,
        'batch_id', 261,
        'from_stock_location_id', 2,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-vehicle-batch-consumed',
        'note', 'Přeřazení již spotřebovaného 1 ks z vozidla na FEFO šarži 261'
      ),
      jsonb_build_object(
        'product_id', 99,
        'batch_id', null,
        'from_stock_location_id', null,
        'to_stock_location_id', 2,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-vehicle-unbatched-clear',
        'note', 'Vynulování záporného nešaržového zůstatku po přiřazení spotřeby k šarži 261'
      ),
      jsonb_build_object(
        'product_id', 99,
        'batch_id', null,
        'from_stock_location_id', 31,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-rigum-unbatched-clear',
        'note', 'Přeřazení doplněného 1 ks v RIGUMu z nešaržového zůstatku'
      ),
      jsonb_build_object(
        'product_id', 99,
        'batch_id', 261,
        'from_stock_location_id', null,
        'to_stock_location_id', 31,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-rigum-batch-261',
        'note', 'Přiřazení doplněného 1 ks v RIGUMu k FEFO šarži 261'
      )
    )
  );
end
$$;

select sl.id stock_location_id, sl.name stock_location_name, b.batch_id,
       ib.use_by_date, ib.best_before_date, b.quantity_on_hand
from public.stock_location_balances b
join public.stock_locations sl on sl.id = b.stock_location_id
left join public.inventory_batches ib on ib.id = b.batch_id
where b.product_id = 99 and sl.id in (1, 2, 31)
order by sl.id, b.batch_id nulls first;

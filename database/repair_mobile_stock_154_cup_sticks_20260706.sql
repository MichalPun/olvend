begin;

do $$
declare
  repair_reference text := 'repair-mobile-stock-154-cup-sticks-20260706';
begin
  if not exists (
    select 1
    from stock_movements_v13
    where reference_type = 'manual_correction'
      and reference_id = repair_reference
  ) then
    update mobile_stock_request_items
       set unit = '1 tyč',
           note = concat_ws(' · ', nullif(note, ''), 'oprava: množství bylo zadáno v tyčích, sklad vede kelímky v ks')
     where id in (1315, 1316);

    update stock_location_balances
       set quantity_on_hand = quantity_on_hand - 392,
           updated_at = now()
     where stock_location_id = 1
       and product_id = 79;

    update stock_location_balances
       set quantity_on_hand = quantity_on_hand + 392,
           updated_at = now()
     where stock_location_id = 3
       and product_id = 79;

    update stock_location_balances
       set quantity_on_hand = quantity_on_hand - 1715,
           updated_at = now()
     where stock_location_id = 1
       and product_id = 80;

    update stock_location_balances
       set quantity_on_hand = quantity_on_hand + 1715,
           updated_at = now()
     where stock_location_id = 3
       and product_id = 80;

    insert into stock_movements_v13 (
      product_id,
      from_stock_location_id,
      to_stock_location_id,
      movement_type,
      quantity_base_units,
      reference_type,
      reference_id,
      note
    )
    values
      (79, 1, 3, 'load_vehicle', 392, 'manual_correction', repair_reference, 'Oprava mobilní nakládky #154: Kelímek 250 ml bylo 8 tyčí, propsalo se jen 8 ks; doplněn rozdíl 392 ks.'),
      (80, 1, 3, 'load_vehicle', 1715, 'manual_correction', repair_reference, 'Oprava mobilní nakládky #154: Kelímek 300 ml bylo 35 tyčí, propsalo se jen 35 ks; doplněn rozdíl 1715 ks.');
  end if;
end $$;

commit;

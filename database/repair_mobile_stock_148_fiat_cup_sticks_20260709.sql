begin;

do $$
declare
  repair_reference text := 'repair-mobile-stock-148-fiat-cup-sticks-20260709';
begin
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_correction'
      and reference_id = repair_reference
  ) then
    update public.mobile_stock_request_items
       set unit = '1 tyč',
           note = concat_ws(' · ', nullif(note, ''), 'oprava: množství bylo zadáno v tyčích, sklad vede kelímky v ks')
     where id in (1187, 1198);

    update public.stock_location_balances
       set quantity_on_hand = quantity_on_hand - 784,
           updated_at = now()
     where stock_location_id = 1
       and product_id = 78;

    update public.stock_location_balances
       set quantity_on_hand = quantity_on_hand + 784,
           updated_at = now()
     where stock_location_id = 4
       and product_id = 78;

    update public.stock_location_balances
       set quantity_on_hand = quantity_on_hand - 98,
           updated_at = now()
     where stock_location_id = 1
       and product_id = 79;

    update public.stock_location_balances
       set quantity_on_hand = quantity_on_hand + 98,
           updated_at = now()
     where stock_location_id = 4
       and product_id = 79;

    insert into public.stock_movements_v13 (
      product_id,
      from_stock_location_id,
      to_stock_location_id,
      movement_type,
      quantity_base_units,
      package_id,
      package_count,
      reference_type,
      reference_id,
      note
    )
    values
      (78, 1, 4, 'load_vehicle', 784, 24, 15.68, 'manual_correction', repair_reference, 'Oprava mobilní nakládky #148 Fiat Doblo: Kelímek 180 ml bylo 16 tyčí, propsalo se jen 16 ks; doplněn rozdíl 784 ks.'),
      (79, 1, 4, 'load_vehicle', 98, 25, 1.96, 'manual_correction', repair_reference, 'Oprava mobilní nakládky #148 Fiat Doblo: Kelímek 250 ml bylo 2 tyče, propsalo se jen 2 ks; doplněn rozdíl 98 ks.');
  end if;
end $$;

commit;

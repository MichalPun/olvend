begin;

do $$
declare
  v_request_id constant bigint := 296;
  v_reference_id constant text := 'repair-duplicate-mobile-stock-296-20260810';
  v_vehicle_location_id constant bigint := 3;
  v_warehouse_location_id constant bigint := 1;
  v_expected_rows integer;
  v_expected_quantity numeric;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = v_reference_id
  ) then
    raise notice 'Oprava duplicitni nakladky #296 uz byla provedena.';
    return;
  end if;

  if not exists (
    select 1
    from public.mobile_stock_requests
    where id = v_request_id
      and status = 'confirmed'
      and vehicle_id = 2
      and requested_for_date = date '2026-08-10'
      and calculation_source = 'manual'
  ) then
    raise exception 'Doklad #296 nema ocekavany stav.';
  end if;

  select count(*), sum(quantity_base_units)
  into v_expected_rows, v_expected_quantity
  from public.stock_movements_v13
  where reference_type = 'mobile_stock_request'
    and reference_id = 'mobile-stock:296'
    and movement_type = 'load_vehicle'
    and from_stock_location_id = v_warehouse_location_id
    and to_stock_location_id = v_vehicle_location_id;

  if v_expected_rows <> 8 or v_expected_quantity <> 76 then
    raise exception 'Pohyby dokladu #296 neodpovidaji ocekavanym 8 radkum / 76 ks.';
  end if;

  if exists (
    select 1
    from (
      select product_id, batch_id, sum(quantity_base_units) as quantity
      from public.stock_movements_v13
      where reference_type = 'mobile_stock_request'
        and reference_id = 'mobile-stock:296'
        and movement_type = 'load_vehicle'
        and from_stock_location_id = v_warehouse_location_id
        and to_stock_location_id = v_vehicle_location_id
      group by product_id, batch_id
    ) expected
    left join public.stock_location_balances balance
      on balance.stock_location_id = v_vehicle_location_id
     and balance.product_id = expected.product_id
     and balance.batch_id is not distinct from expected.batch_id
    where coalesce(balance.quantity_on_hand, 0) <> expected.quantity
      and not (
        expected.product_id = 14
        and expected.batch_id = 438
        and expected.quantity = 13
        and coalesce(balance.quantity_on_hand, 0) = 11
      )
  ) then
    raise exception 'Aktualni sarzove zustatky Vivara se jiz neshoduji s duplicitnim dokladem #296.';
  end if;

  perform public.apply_stock_movements_v13(
    (
      select jsonb_agg(
        jsonb_build_object(
          'product_id', movement.product_id,
          'batch_id', movement.batch_id,
          'from_stock_location_id', v_vehicle_location_id,
          'to_stock_location_id', v_warehouse_location_id,
          'movement_type', 'return',
          'quantity_base_units', movement.quantity,
          'allow_negative_source', true,
          'unit_price', null,
          'reference_type', 'data_repair',
          'reference_id', v_reference_id,
          'note', 'Storno duplicitni mobilni nakladky #296 Michaela Nerudova'
        )
        order by movement.product_id, movement.batch_id nulls last
      )
      from (
        select product_id, batch_id, sum(quantity_base_units) as quantity
        from public.stock_movements_v13
        where reference_type = 'mobile_stock_request'
          and reference_id = 'mobile-stock:296'
          and movement_type = 'load_vehicle'
          and from_stock_location_id = v_warehouse_location_id
          and to_stock_location_id = v_vehicle_location_id
        group by product_id, batch_id
      ) movement
    )
  );

  update public.mobile_stock_requests
  set status = 'cancelled',
      note = concat_ws(' | ', nullif(note, ''), 'Stornovano 10. 8. 2026: duplicitni nakladka, zasoba vracena z Vivara do BLUCINY.'),
      updated_at = now()
  where id = v_request_id;
end
$$;

commit;

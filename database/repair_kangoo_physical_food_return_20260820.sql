-- Fyzicky ověřená použitelná vratka z Renault Kangoo do skladu Blučina.
-- Knižní stav vozidla byl 0, protože dnešní mobilní návštěvy odečetly celé
-- naložené množství. Korekce nejdřív dorovná fyzický stav vozidla a následně
-- jej vrátí do skladu se zachováním přijatých šarží (expirace 27. 8. 2026).

begin;

do $$
declare
  v_vehicle_location_id bigint;
  v_warehouse_location_id bigint;
  v_before_teriyaki numeric;
  v_before_labusnik numeric;
  v_before_debrecinska numeric;
  v_before_strips numeric;
begin
  select sl.id
    into strict v_vehicle_location_id
  from public.stock_locations sl
  join public.vehicles v on v.id = sl.vehicle_id
  where sl.location_type = 'vehicle'
    and v.plate = '2TX7928';

  select sl.id
    into strict v_warehouse_location_id
  from public.stock_locations sl
  where sl.location_type = 'warehouse'
    and sl.warehouse_id = 1;

  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id like 'kangoo-physical-food-return-20260820-%'
  ) then
    raise exception 'Korekce fyzické vratky Kangoo už byla provedena.';
  end if;

  if exists (
    select 1
    from (values
      (164::bigint, 546::bigint),
      (12::bigint, 548::bigint),
      (17::bigint, 550::bigint),
      (14::bigint, 549::bigint)
    ) expected(product_id, batch_id)
    left join public.inventory_batches ib
      on ib.id = expected.batch_id
     and ib.product_id = expected.product_id
     and coalesce(ib.use_by_date, ib.best_before_date) = date '2026-08-27'
    where ib.id is null
  ) then
    raise exception 'Šarže potravin neodpovídají příjmu s expirací 27. 8. 2026.';
  end if;

  if exists (
    select 1
    from (values (164::bigint), (12::bigint), (17::bigint), (14::bigint)) expected(product_id)
    left join public.stock_location_balances b
      on b.stock_location_id = v_vehicle_location_id
     and b.product_id = expected.product_id
    group by expected.product_id
    having coalesce(sum(b.quantity_on_hand), 0) <> 0
  ) then
    raise exception 'Knižní stav některé opravované položky v Kangoo už není 0.';
  end if;

  select coalesce(sum(quantity_on_hand), 0) into v_before_teriyaki
  from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 164;
  select coalesce(sum(quantity_on_hand), 0) into v_before_labusnik
  from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 12;
  select coalesce(sum(quantity_on_hand), 0) into v_before_debrecinska
  from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 17;
  select coalesce(sum(quantity_on_hand), 0) into v_before_strips
  from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 14;

  -- Nejprve dorovnat fyzicky zjištěný stav vozidla. Samostatné volání zajistí,
  -- že následná vratka vždy čerpá z již existujícího kladného zůstatku.
  perform public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id', 164, 'batch_id', 546,
      'from_stock_location_id', null, 'to_stock_location_id', v_vehicle_location_id,
      'movement_type', 'adjustment', 'quantity_base_units', 2,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-teriyaki-count',
      'note', 'Fyzicky ověřeno v Kangoo: 2 ks Kuře teriyaki; mobilní návštěvy evidovaly vozidlo 0 ks.'
    ),
    jsonb_build_object(
      'product_id', 12, 'batch_id', 548,
      'from_stock_location_id', null, 'to_stock_location_id', v_vehicle_location_id,
      'movement_type', 'adjustment', 'quantity_base_units', 5,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-labusnik-count',
      'note', 'Fyzicky ověřeno v Kangoo: 5 ks Labužník; mobilní návštěvy evidovaly vozidlo 0 ks.'
    ),
    jsonb_build_object(
      'product_id', 17, 'batch_id', 550,
      'from_stock_location_id', null, 'to_stock_location_id', v_vehicle_location_id,
      'movement_type', 'adjustment', 'quantity_base_units', 8,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-debrecinska-count',
      'note', 'Fyzicky ověřeno v Kangoo: 8 ks Debrecínská; mobilní návštěvy evidovaly vozidlo 0 ks.'
    ),
    jsonb_build_object(
      'product_id', 14, 'batch_id', 549,
      'from_stock_location_id', null, 'to_stock_location_id', v_vehicle_location_id,
      'movement_type', 'adjustment', 'quantity_base_units', 15,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-strips-count',
      'note', 'Fyzicky ověřeno v Kangoo: 15 ks Kuřecí stripsy; mobilní návštěvy evidovaly vozidlo 0 ks.'
    )
  ));

  perform public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id', 164, 'batch_id', 546,
      'from_stock_location_id', v_vehicle_location_id, 'to_stock_location_id', v_warehouse_location_id,
      'movement_type', 'return', 'quantity_base_units', 2,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-teriyaki-return',
      'note', 'Použitelná fyzická vratka z Kangoo do skladu Blučina.',
      'allow_negative_source', false
    ),
    jsonb_build_object(
      'product_id', 12, 'batch_id', 548,
      'from_stock_location_id', v_vehicle_location_id, 'to_stock_location_id', v_warehouse_location_id,
      'movement_type', 'return', 'quantity_base_units', 5,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-labusnik-return',
      'note', 'Použitelná fyzická vratka z Kangoo do skladu Blučina.',
      'allow_negative_source', false
    ),
    jsonb_build_object(
      'product_id', 17, 'batch_id', 550,
      'from_stock_location_id', v_vehicle_location_id, 'to_stock_location_id', v_warehouse_location_id,
      'movement_type', 'return', 'quantity_base_units', 8,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-debrecinska-return',
      'note', 'Použitelná fyzická vratka z Kangoo do skladu Blučina.',
      'allow_negative_source', false
    ),
    jsonb_build_object(
      'product_id', 14, 'batch_id', 549,
      'from_stock_location_id', v_vehicle_location_id, 'to_stock_location_id', v_warehouse_location_id,
      'movement_type', 'return', 'quantity_base_units', 15,
      'reference_type', 'data_repair',
      'reference_id', 'kangoo-physical-food-return-20260820-strips-return',
      'note', 'Použitelná fyzická vratka z Kangoo do skladu Blučina.',
      'allow_negative_source', false
    )
  ));

  if (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_vehicle_location_id and product_id = 164) <> 0
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_vehicle_location_id and product_id = 12) <> 0
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_vehicle_location_id and product_id = 17) <> 0
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_vehicle_location_id and product_id = 14) <> 0 then
    raise exception 'Po vratce nezůstal stav opravovaných položek v Kangoo na 0.';
  end if;

  if (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 164) <> v_before_teriyaki + 2
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 12) <> v_before_labusnik + 5
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 17) <> v_before_debrecinska + 8
    or (select coalesce(sum(quantity_on_hand), 0) from public.stock_location_balances where stock_location_id = v_warehouse_location_id and product_id = 14) <> v_before_strips + 15 then
    raise exception 'Sklad Blučina nebyl navýšen přesně o fyzicky vrácené množství.';
  end if;
end
$$;

commit;

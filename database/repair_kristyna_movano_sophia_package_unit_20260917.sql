begin;

do $$
declare
  v_repair_reference constant text := 'repair-kristyna-movano-sophia-package-unit-20260917';
  v_employee_id constant uuid := '9133f82b-89a6-4581-955c-d2138b947a8d';
  v_request_id constant bigint := 445;
  v_request_item_id constant bigint := 4208;
  v_product_id constant bigint := 108;
  v_batch_id constant bigint := 774;
  v_vehicle_id constant bigint := 4;
  v_vehicle_location_id constant bigint := 58;
  v_warehouse_location_id constant bigint := 1;
  v_vehicle_batch_quantity numeric(12,3);
  v_vehicle_total_quantity numeric(12,3);
  v_reserved_quantity numeric(12,3);
  v_warehouse_batch_quantity numeric(12,3);
begin
  perform pg_advisory_xact_lock(hashtextextended(v_repair_reference, 0));

  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = v_repair_reference
  ) then
    raise exception 'Repair % has already been applied', v_repair_reference;
  end if;

  if not exists (
    select 1
    from public.products
    where id = v_product_id
      and sku = '44'
      and base_unit = 'kg'
      and name = 'oVe FD COFFEE SOPHIA 500g'
  ) then
    raise exception 'Sophia product card no longer matches the audited state';
  end if;

  if not exists (
    select 1
    from public.stock_locations
    where id = v_vehicle_location_id
      and location_type = 'vehicle'
      and vehicle_id = v_vehicle_id
      and active = true
  ) then
    raise exception 'Audited Opel Movano stock location no longer matches';
  end if;

  if not exists (
    select 1
    from public.mobile_stock_requests
    where id = v_request_id
      and request_type = 'vehicle_load'
      and status = 'confirmed'
      and employee_id = v_employee_id
      and vehicle_id = v_vehicle_id
  ) then
    raise exception 'Audited Kristyna load request no longer matches';
  end if;

  if not exists (
    select 1
    from public.mobile_stock_request_items
    where id = v_request_item_id
      and request_id = v_request_id
      and product_id = v_product_id
      and unit = 'kg'
      and requested_quantity = 6
      and prepared_quantity = 6
      and confirmed_quantity is null
  ) then
    raise exception 'Audited Sophia load item no longer matches';
  end if;

  select
    coalesce(sum(quantity_on_hand) filter (where batch_id = v_batch_id), 0),
    coalesce(sum(quantity_on_hand), 0),
    coalesce(sum(reserved_quantity), 0)
  into v_vehicle_batch_quantity, v_vehicle_total_quantity, v_reserved_quantity
  from public.stock_location_balances
  where stock_location_id = v_vehicle_location_id
    and product_id = v_product_id;

  if v_vehicle_batch_quantity <> 3 or v_vehicle_total_quantity <> 3 or v_reserved_quantity <> 0 then
    raise exception 'Movano Sophia balance changed: batch %, total %, reserved %',
      v_vehicle_batch_quantity, v_vehicle_total_quantity, v_reserved_quantity;
  end if;

  select coalesce(sum(quantity_on_hand), 0)
  into v_warehouse_batch_quantity
  from public.stock_location_balances
  where stock_location_id = v_warehouse_location_id
    and product_id = v_product_id
    and batch_id = v_batch_id;

  if v_warehouse_batch_quantity <> 23 then
    raise exception 'Blucina Sophia batch balance changed: %', v_warehouse_batch_quantity;
  end if;

  perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
    'product_id', v_product_id,
    'batch_id', v_batch_id,
    'from_stock_location_id', v_vehicle_location_id,
    'to_stock_location_id', v_warehouse_location_id,
    'movement_type', 'return',
    'quantity_base_units', 3,
    'reference_type', 'data_repair',
    'reference_id', v_repair_reference,
    'note', 'Oprava jednotky nakládky #445: 6 balení Sophia po 500 g = 3 kg, nikoli 6 kg.'
  )));

  update public.mobile_stock_request_items
  set
    unit = '0,5 kg',
    confirmed_quantity = 6,
    note = concat_ws(' · ', nullif(note, ''), 'Audit 17. 9. 2026: 6 balení × 0,5 kg = 3 kg')
  where id = v_request_item_id;

  update public.mobile_stock_requests
  set note = concat_ws(' · ', nullif(note, ''), 'Audit 17. 9. 2026: opravena jednotka Sophie; 6 balení = 3 kg')
  where id = v_request_id;

  select coalesce(sum(quantity_on_hand), 0)
  into v_vehicle_total_quantity
  from public.stock_location_balances
  where stock_location_id = v_vehicle_location_id
    and product_id = v_product_id;

  if v_vehicle_total_quantity <> 0 then
    raise exception 'Repair did not zero Movano Sophia balance: %', v_vehicle_total_quantity;
  end if;

  select coalesce(sum(quantity_on_hand), 0)
  into v_warehouse_batch_quantity
  from public.stock_location_balances
  where stock_location_id = v_warehouse_location_id
    and product_id = v_product_id
    and batch_id = v_batch_id;

  if v_warehouse_batch_quantity <> 26 then
    raise exception 'Repair did not restore Blucina Sophia batch: %', v_warehouse_batch_quantity;
  end if;
end;
$$;

commit;

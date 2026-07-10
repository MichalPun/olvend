-- Oprava Sophia na Opel Vivaro.
-- Sophia je vedena v kg, ale fyzicky ma karton 10 x 0,5 kg = 5 kg.
-- Nakladka #156 byla pri vychystani propsana jako 10 kg, proto vracime nadhodnocenych 5 kg
-- z vozidla zpet na sklad a zbytek nulujeme inventurnim dorovnanim podle fyzicke kontroly.

update public.mobile_stock_request_items
set prepared_quantity = 5,
    note = concat_ws(
      ' · ',
      nullif(note, ''),
      'Oprava 10. 7. 2026: karton Sophia = 10 x 0,5 kg, tedy 5 kg; puvodne bylo vychystani zapsane jako 10 kg.'
    ),
    updated_at = now()
where id = 1340
  and request_id = 156
  and product_id = 108
  and prepared_quantity = 10;

select public.apply_stock_movements_v13(
  jsonb_build_array(
    jsonb_build_object(
      'product_id', 108,
      'batch_id', null,
      'from_stock_location_id', 3,
      'to_stock_location_id', 1,
      'movement_type', 'return',
      'quantity_base_units', 5,
      'unit_price', null,
      'reference_type', 'data_repair',
      'reference_id', 'repair-vivaro-sophia-package-20260710',
      'note', '2026-07-10 · oprava nakladky #156 Sophia: karton 10 x 0,5 kg = 5 kg, ne 10 kg'
    ),
    jsonb_build_object(
      'product_id', 108,
      'batch_id', null,
      'from_stock_location_id', 3,
      'to_stock_location_id', null,
      'movement_type', 'adjustment',
      'quantity_base_units', 6.5,
      'unit_price', null,
      'reference_type', 'vehicle_inventory_audit_correction',
      'reference_id', 'repair-vivaro-sophia-zero-20260710',
      'note', '2026-07-10 · inventurni dorovnani Sophia na Opel Vivaro na 0 kg podle fyzicke kontroly operatorky'
    )
  )
) as result;

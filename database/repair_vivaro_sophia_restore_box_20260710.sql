-- Navraceni Sophia na Opel Vivaro po upresneni fyzicke kontroly.
-- Operatorka potvrdila, ze na vozidle ma celou bednu: 10 x 0,5 kg = 5 kg.
-- Oprava kartonu #156 zustava spravne na 5 kg; vracime jen cast predchoziho vynulovani.

select public.apply_stock_movements_v13(
  jsonb_build_array(
    jsonb_build_object(
      'product_id', 108,
      'batch_id', null,
      'from_stock_location_id', null,
      'to_stock_location_id', 3,
      'movement_type', 'adjustment',
      'quantity_base_units', 5,
      'unit_price', null,
      'reference_type', 'vehicle_inventory_audit_correction',
      'reference_id', 'repair-vivaro-sophia-restore-box-20260710',
      'note', '2026-07-10 · oprava fyzicke kontroly Sophia na Opel Vivaro: operatorka potvrdila celou bednu 10 x 0,5 kg = 5 kg'
    )
  )
) as result;

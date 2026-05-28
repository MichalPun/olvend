update public.stock_movements_v13
set movement_type = 'sale_revenue'
where movement_type = 'sale'
  and reference_type = 'manual_sale'
  and from_stock_location_id is null
  and to_stock_location_id is null
  and coalesce(note, '') ilike '%tržba za složenou kartu%';

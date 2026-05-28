alter table public.stock_movements_v13
  drop constraint if exists stock_movements_v13_movement_type_check;

alter table public.stock_movements_v13
  add constraint stock_movements_v13_movement_type_check
  check (movement_type in (
    'receipt',
    'transfer',
    'load_vehicle',
    'fill_machine',
    'sale',
    'sale_revenue',
    'consumption',
    'return',
    'adjustment',
    'waste'
  ));

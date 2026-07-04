alter table public.purchase_order_items
  alter column unit_cost type numeric(12,4);

alter table public.stock_movements_v13
  alter column unit_price type numeric(12,4);

alter table public.supplier_product_mappings
  alter column last_unit_price type numeric(12,4);

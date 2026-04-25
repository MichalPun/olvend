alter table public.purchase_orders
  add column if not exists delivery_note_number text,
  add column if not exists invoice_number text,
  add column if not exists received_at timestamp with time zone,
  add column if not exists received_stock_location_id bigint references public.stock_locations (id) on delete set null;

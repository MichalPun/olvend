alter table public.vehicle_operation_logs
  add column if not exists fuel_receipt_url text;

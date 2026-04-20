alter table public.vehicle_operation_logs
  add column if not exists fuel_odometer_km integer;


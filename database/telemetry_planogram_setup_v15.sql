alter table public.machine_planogram_slots
  add column if not exists dex_price_czk numeric(10,2),
  add column if not exists last_units integer,
  add column if not exists desired_units integer,
  add column if not exists expiry_date date,
  add column if not exists telemetry_key text;

create index if not exists machine_planogram_slots_telemetry_key_idx
  on public.machine_planogram_slots (machine_id, telemetry_key)
  where telemetry_key is not null;

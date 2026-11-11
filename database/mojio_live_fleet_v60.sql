begin;

create table if not exists public.vehicle_live_positions (
  mojio_vehicle_id text primary key,
  vehicle_name text not null,
  is_online boolean not null default false,
  is_parked boolean not null default true,
  latitude double precision,
  longitude double precision,
  address text,
  heading_degrees numeric(7,2),
  odometer_km numeric(14,2),
  fuel_value numeric(12,3),
  fuel_unit text,
  battery_volts numeric(10,3),
  issue_count integer not null default 0,
  diagnostic_codes jsonb not null default '[]'::jsonb,
  source_updated_at timestamptz,
  ingested_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint vehicle_live_positions_latitude_check check (latitude is null or latitude between -90 and 90),
  constraint vehicle_live_positions_longitude_check check (longitude is null or longitude between -180 and 180),
  constraint vehicle_live_positions_issue_count_check check (issue_count between 0 and 1000),
  constraint vehicle_live_positions_diagnostic_codes_check check (jsonb_typeof(diagnostic_codes) = 'array')
);

create index if not exists vehicle_live_positions_ingested_at_idx
  on public.vehicle_live_positions (ingested_at desc);

alter table public.vehicle_live_positions enable row level security;

drop policy if exists "Authenticated read live vehicle positions" on public.vehicle_live_positions;
create policy "Authenticated read live vehicle positions"
on public.vehicle_live_positions
for select
to authenticated
using (public.security_active_employee());

revoke all on public.vehicle_live_positions from public, anon;
grant select on public.vehicle_live_positions to authenticated;

comment on table public.vehicle_live_positions is
  'Sanitized current vehicle positions synchronized from the user-authorized T-Mobile Motion browser connector. Mojio credentials and tokens are never stored here.';

commit;

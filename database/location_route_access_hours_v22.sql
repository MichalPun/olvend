alter table public.locations
  add column if not exists route_access_hours jsonb,
  add column if not exists route_access_status text not null default 'needs_confirmation',
  add column if not exists route_access_source text,
  add column if not exists route_access_verified_at timestamptz;

alter table public.locations
  drop constraint if exists locations_route_access_status_check;

alter table public.locations
  add constraint locations_route_access_status_check
  check (route_access_status in ('confirmed', 'unrestricted', 'needs_confirmation'));

comment on column public.locations.route_access_hours is
  'Operational access windows for route planning. Keys: mo,tu,we,th,fr,sa,su; values are arrays of [HH:MM,HH:MM].';
comment on column public.locations.route_access_status is
  'confirmed = usable for automatic planning, unrestricted = no access restriction, needs_confirmation = excluded from recommended planning.';

-- Veřejně potvrzená sezónní provozní doba koupaliště pro rok 2026.
update public.locations
set route_access_hours = '{"mo":[["10:00","20:00"]],"tu":[["10:00","20:00"]],"we":[["10:00","20:00"]],"th":[["10:00","20:00"]],"fr":[["10:00","20:00"]],"sa":[["10:00","20:00"]],"su":[["10:00","20:00"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'https://www.osicko.cz/organizace/koupaliste/provozni-doba/',
    route_access_verified_at = now(),
    service_window = 'po–ne 10:00–20:00'
where id = 74;

-- Tato interní lokalita je v evidenci již vedena jako nepřetržitě přístupná.
update public.locations
set route_access_hours = '{"mo":[["00:00","24:00"]],"tu":[["00:00","24:00"]],"we":[["00:00","24:00"]],"th":[["00:00","24:00"]],"fr":[["00:00","24:00"]],"sa":[["00:00","24:00"]],"su":[["00:00","24:00"]]}'::jsonb,
    route_access_status = 'confirmed',
    route_access_source = 'OLVEND service_window',
    route_access_verified_at = now()
where id = 70;

create index if not exists locations_route_access_status_idx
  on public.locations (route_access_status)
  where active is true;

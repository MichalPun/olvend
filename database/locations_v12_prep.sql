alter table public.locations
  add column if not exists service_priority text,
  add column if not exists service_frequency text,
  add column if not exists service_plan_note text,
  add column if not exists latitude numeric(10, 7),
  add column if not exists longitude numeric(10, 7);

alter table public.locations
  drop constraint if exists locations_service_priority_check;

alter table public.locations
  add constraint locations_service_priority_check
  check (service_priority in ('low', 'normal', 'high', 'critical') or service_priority is null);

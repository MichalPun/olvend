alter table public.locations
  add column if not exists location_priority text,
  add column if not exists recommended_priority text,
  add column if not exists priority_reviewed_at date,
  add column if not exists priority_note text;

alter table public.locations
  drop constraint if exists locations_location_priority_check;

alter table public.locations
  add constraint locations_location_priority_check
  check (location_priority in ('A', 'B', 'C') or location_priority is null);

alter table public.locations
  drop constraint if exists locations_recommended_priority_check;

alter table public.locations
  add constraint locations_recommended_priority_check
  check (recommended_priority in ('A', 'B', 'C', 'review') or recommended_priority is null);

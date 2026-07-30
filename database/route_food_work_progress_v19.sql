begin;

alter table public.route_machine_visits
  add column if not exists work_phase text not null default 'picklist',
  add column if not exists food_preparation jsonb not null default '{}'::jsonb;

alter table public.route_machine_visits
  drop constraint if exists route_machine_visits_work_phase_check;

alter table public.route_machine_visits
  add constraint route_machine_visits_work_phase_check
  check (work_phase in ('picklist', 'machine'));

commit;

notify pgrst, 'reload schema';

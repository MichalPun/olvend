alter table public.machine_service_rules
  add column if not exists route_planning_paused_until date,
  add column if not exists route_planning_excluded_months smallint[] not null default '{}'::smallint[],
  add column if not exists route_planning_note text;

alter table public.machine_service_rules
  drop constraint if exists machine_service_rules_route_planning_months_check;

alter table public.machine_service_rules
  add constraint machine_service_rules_route_planning_months_check
  check (
    route_planning_excluded_months <@ array[1,2,3,4,5,6,7,8,9,10,11,12]::smallint[]
  );

comment on column public.machine_service_rules.route_planning_paused_until is
  'Včetně tohoto data se automat nenabízí do automaticky sestavených tras ani provozních upozornění.';
comment on column public.machine_service_rules.route_planning_excluded_months is
  'Opakované kalendářní měsíce, ve kterých se automat automaticky neplánuje.';
comment on column public.machine_service_rules.route_planning_note is
  'Interní důvod plánovací výjimky zobrazený v nastavení automatu.';

insert into public.machine_service_rules (
  machine_id,
  route_planning_excluded_months,
  route_planning_note
)
select
  m.id,
  array[7,8]::smallint[],
  'Letní prázdniny'
from public.machines m
where m.evidence_number in (18, 20, 35, 45)
on conflict (machine_id) do update
set
  route_planning_excluded_months = excluded.route_planning_excluded_months,
  route_planning_note = coalesce(public.machine_service_rules.route_planning_note, excluded.route_planning_note);

-- EV103 · BVK Hády · Kristýna · návštěva 1922 · 19. 11. 2026
-- Bez zásahu do fyzických zásob znovu otevře Z1 a Z2, které se v mobilu
-- chybně označily jako hotové ještě před úspěšným uložením skutečného stavu.

begin;

create table if not exists public.reopen_kristyna_ev103_visit1922_audit_20261119 (
  repair_key text primary key,
  before_state jsonb not null,
  after_state jsonb,
  repaired_at timestamptz not null default now()
);

alter table public.reopen_kristyna_ev103_visit1922_audit_20261119 enable row level security;
revoke all on table public.reopen_kristyna_ev103_visit1922_audit_20261119
  from public, anon, authenticated;
grant all on table public.reopen_kristyna_ev103_visit1922_audit_20261119 to service_role;

do $$
declare
  v_key constant text := 'ev103-visit1922-reopen-z1-z2';
  v_visit public.route_machine_visits%rowtype;
  v_preparation jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(v_key, 0));

  if exists (
    select 1
    from public.reopen_kristyna_ev103_visit1922_audit_20261119
    where repair_key = v_key and after_state is not null
  ) then
    raise notice 'Z1 a Z2 návštěvy 1922 už byly znovu otevřeny.';
    return;
  end if;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 1922
    and machine_id = 83
    and route_plan_id = 216
    and route_plan_stop_id = 2681
    and employee_id = '9133f82b-89a6-4581-955c-d2138b947a8d'::uuid
    and status = 'arrived'
  for update;

  if exists (
    select 1 from public.route_machine_visit_items
    where visit_id = 1922 and coffee_container_id in (528, 529)
  ) then
    raise exception 'Z1 nebo Z2 už má uložený skutečný stav; znovuotevření se zastavilo.';
  end if;

  if coalesce((v_visit.coffee_preparation #>> '{containers,528,accepted}')::boolean, false) is not true
     or coalesce((v_visit.coffee_preparation #>> '{containers,528,packages}')::numeric, -1) <> 2
     or coalesce((v_visit.coffee_preparation #>> '{containers,528,movedPackages}')::numeric, -1) <> 2 then
    raise exception 'Z1 už nemá očekávaný chybný stav: %.', v_visit.coffee_preparation #> '{containers,528}';
  end if;

  if coalesce((v_visit.coffee_preparation #>> '{containers,529,accepted}')::boolean, false) is not true
     or coalesce((v_visit.coffee_preparation #>> '{containers,529,packages}')::numeric, -1) <> 0
     or coalesce((v_visit.coffee_preparation #>> '{containers,529,movedPackages}')::numeric, -1) <> 1 then
    raise exception 'Z2 už nemá očekávaný chybný stav: %.', v_visit.coffee_preparation #> '{containers,529}';
  end if;

  insert into public.reopen_kristyna_ev103_visit1922_audit_20261119 (
    repair_key, before_state
  ) values (
    v_key,
    jsonb_build_object(
      'visit_id', v_visit.id,
      'status', v_visit.status,
      'work_phase', v_visit.work_phase,
      'z1', v_visit.coffee_preparation #> '{containers,528}',
      'z2', v_visit.coffee_preparation #> '{containers,529}'
    )
  );

  v_preparation := jsonb_set(
    jsonb_set(v_visit.coffee_preparation, '{containers,528,accepted}', 'false'::jsonb, true),
    '{containers,529,accepted}', 'false'::jsonb, true
  );

  update public.route_machine_visits
  set coffee_preparation = v_preparation,
      work_phase = 'machine',
      synced_at = now(),
      updated_at = now()
  where id = 1922 and status = 'arrived';

  if not found then
    raise exception 'Návštěvu 1922 se nepodařilo znovu otevřít.';
  end if;

  update public.reopen_kristyna_ev103_visit1922_audit_20261119
  set after_state = jsonb_build_object(
        'visit_id', 1922,
        'status', (select status from public.route_machine_visits where id = 1922),
        'work_phase', (select work_phase from public.route_machine_visits where id = 1922),
        'z1', (select coffee_preparation #> '{containers,528}' from public.route_machine_visits where id = 1922),
        'z2', (select coffee_preparation #> '{containers,529}' from public.route_machine_visits where id = 1922)
      ),
      repaired_at = now()
  where repair_key = v_key;
end
$$;

commit;

select
  id,
  status,
  work_phase,
  coffee_preparation #>> '{containers,528,accepted}' as z1_accepted,
  coffee_preparation #>> '{containers,529,accepted}' as z2_accepted
from public.route_machine_visits
where id = 1922;

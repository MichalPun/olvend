-- David Boudny, Sportisimo EV 98, visit #1533 on 2026-10-29.
-- The operator finished every mobile step at approximately 09:35 Europe/Prague,
-- but completion was blocked because the historical full calibration from
-- 2026-07-29 had not been copied into machines.stock_initialized_at.

begin;

create table if not exists public.repair_david_ev98_completion_20261029_audit (
  repair_key text primary key,
  before_state jsonb not null,
  after_state jsonb,
  repaired_at timestamptz not null default now()
);

do $$
declare
  v_repair_key constant text := 'david-ev98-visit1533-completion-20261029';
  v_visit_id constant bigint := 1533;
  v_machine_id constant bigint := 78;
  v_stop_id constant bigint := 2214;
  v_z8_item_id constant bigint := 43240;
  v_completed_at constant timestamptz := '2026-10-29 08:35:16+00';
begin
  perform pg_advisory_xact_lock(hashtextextended(v_repair_key, 0));

  if exists (
    select 1
    from public.repair_david_ev98_completion_20261029_audit
    where repair_key = v_repair_key
      and after_state is not null
  ) then
    return;
  end if;

  if not exists (
    select 1
    from public.route_machine_visits visit
    join public.machines machine on machine.id = visit.machine_id
    join public.employees employee on employee.id = visit.employee_id
    where visit.id = v_visit_id
      and visit.machine_id = v_machine_id
      and visit.route_plan_stop_id = v_stop_id
      and visit.visit_date = date '2026-10-29'
      and visit.status = 'arrived'
      and machine.evidence_number = 98
      and employee.name = 'David'
      and employee.surname = 'Boudný'
  ) then
    raise exception 'Visit #1533 no longer matches the open David Boudny visit at EV 98.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = v_machine_id
      and stock_initialized_at = '2026-07-29 12:10:33.667+00'::timestamptz
  ) then
    raise exception 'EV 98 historical calibration was not backfilled before completion repair.';
  end if;

  if not exists (
    select 1
    from public.route_machine_visit_items item
    where item.id = v_z8_item_id
      and item.visit_id = v_visit_id
      and item.machine_id = v_machine_id
      and item.coffee_container_id = 494
      and item.physical_position_label = 'Z8'
      and item.actual_before_quantity = 0
      and item.actual_add_quantity = 0
      and item.final_quantity = 0
      and item.accepted_at is not null
  ) then
    raise exception 'EV 98 visit #1533 Z8 confirmation changed; repair aborted.';
  end if;

  if not exists (
    select 1
    from public.route_machine_visits visit
    where visit.id = v_visit_id
      and visit.coffee_preparation #>> '{containers,494,pickDecision}' = 'skipped'
      and visit.coffee_preparation #>> '{containers,494,pickSkipReason}' = 'Není ve vozidle'
      and coalesce((visit.coffee_preparation #>> '{containers,494,accepted}')::boolean, false)
  ) then
    raise exception 'EV 98 visit #1533 no longer records David''s accepted Z8 missing-vehicle-stock decision.';
  end if;

  insert into public.repair_david_ev98_completion_20261029_audit (repair_key, before_state)
  values (
    v_repair_key,
    jsonb_build_object(
      'visit', (select to_jsonb(visit) from public.route_machine_visits visit where visit.id = v_visit_id),
      'stop', (select to_jsonb(stop) from public.route_plan_stops stop where stop.id = v_stop_id),
      'machine', (select to_jsonb(machine) from public.machines machine where machine.id = v_machine_id),
      'z8_item', (select to_jsonb(item) from public.route_machine_visit_items item where item.id = v_z8_item_id)
    )
  )
  on conflict (repair_key) do nothing;

  update public.route_machine_visits
  set status = 'completed',
      completed_at = v_completed_at,
      synced_at = now(),
      updated_at = now()
  where id = v_visit_id;

  if not exists (
    select 1
    from public.route_machine_visits visit
    join public.route_plan_stops stop on stop.id = visit.route_plan_stop_id
    where visit.id = v_visit_id
      and visit.status = 'completed'
      and visit.completed_at = v_completed_at
      and stop.id = v_stop_id
      and stop.status = 'done'
      and stop.completed_at = v_completed_at
  ) then
    raise exception 'EV 98 visit/stop completion did not persist consistently.';
  end if;

  update public.repair_david_ev98_completion_20261029_audit
  set after_state = jsonb_build_object(
    'visit', (select to_jsonb(visit) from public.route_machine_visits visit where visit.id = v_visit_id),
    'stop', (select to_jsonb(stop) from public.route_plan_stops stop where stop.id = v_stop_id),
    'machine', (select to_jsonb(machine) from public.machines machine where machine.id = v_machine_id),
    'z8_item', (select to_jsonb(item) from public.route_machine_visit_items item where item.id = v_z8_item_id)
  )
  where repair_key = v_repair_key;
end $$;

commit;

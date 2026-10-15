-- Keep the route stop and its mobile machine visit in the same terminal state.
-- Mobile offline sync can deliver the two PATCH requests independently; either
-- accepted half therefore completes the other half inside the database.

begin;

create or replace function public.sync_route_visit_state_from_stop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'done' and new.completed_at is not null then
    update public.route_machine_visits visit
    set status = 'completed',
        completed_at = new.completed_at,
        synced_at = greatest(coalesce(visit.synced_at, new.completed_at), new.completed_at),
        updated_at = now()
    where visit.route_plan_stop_id = new.id
      and visit.route_plan_id = new.route_plan_id
      and visit.machine_id = new.machine_id
      and (
        visit.status is distinct from 'completed'
        or visit.completed_at is distinct from new.completed_at
      );
  elsif new.status = 'skipped' and new.skipped_at is not null then
    update public.route_machine_visits visit
    set status = 'skipped',
        skipped_at = new.skipped_at,
        synced_at = greatest(coalesce(visit.synced_at, new.skipped_at), new.skipped_at),
        updated_at = now()
    where visit.route_plan_stop_id = new.id
      and visit.route_plan_id = new.route_plan_id
      and visit.machine_id = new.machine_id
      and (
        visit.status is distinct from 'skipped'
        or visit.skipped_at is distinct from new.skipped_at
      );
  end if;

  return new;
end $$;

drop trigger if exists trg_route_stop_sync_machine_visit_state
  on public.route_plan_stops;

create trigger trg_route_stop_sync_machine_visit_state
after insert or update of status, completed_at, skipped_at
on public.route_plan_stops
for each row
when (
  (new.status = 'done' and new.completed_at is not null)
  or (new.status = 'skipped' and new.skipped_at is not null)
)
execute function public.sync_route_visit_state_from_stop();

create or replace function public.sync_route_stop_state_from_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.route_plan_stop_id is null then
    return new;
  end if;

  if new.status = 'completed' and new.completed_at is not null then
    update public.route_plan_stops stop
    set status = 'done',
        completed_at = new.completed_at
    where stop.id = new.route_plan_stop_id
      and stop.route_plan_id = new.route_plan_id
      and stop.machine_id = new.machine_id
      and (
        stop.status is distinct from 'done'
        or stop.completed_at is distinct from new.completed_at
      );
  elsif new.status = 'skipped' and new.skipped_at is not null then
    update public.route_plan_stops stop
    set status = 'skipped',
        skipped_at = new.skipped_at
    where stop.id = new.route_plan_stop_id
      and stop.route_plan_id = new.route_plan_id
      and stop.machine_id = new.machine_id
      and (
        stop.status is distinct from 'skipped'
        or stop.skipped_at is distinct from new.skipped_at
      );
  end if;

  return new;
end $$;

drop trigger if exists trg_machine_visit_sync_route_stop_state
  on public.route_machine_visits;

create trigger trg_machine_visit_sync_route_stop_state
after insert or update of status, completed_at, skipped_at
on public.route_machine_visits
for each row
when (
  (new.status = 'completed' and new.completed_at is not null)
  or (new.status = 'skipped' and new.skipped_at is not null)
)
execute function public.sync_route_stop_state_from_visit();

-- Repair historical half-completed pairs. A closed route stop is authoritative
-- when its visit was left open by an interrupted/offline dual write.
update public.route_machine_visits visit
set status = case stop.status when 'done' then 'completed' else 'skipped' end,
    completed_at = case when stop.status = 'done' then stop.completed_at else visit.completed_at end,
    skipped_at = case when stop.status = 'skipped' then stop.skipped_at else visit.skipped_at end,
    synced_at = greatest(
      coalesce(visit.synced_at, '-infinity'::timestamptz),
      coalesce(stop.completed_at, stop.skipped_at, '-infinity'::timestamptz)
    ),
    updated_at = now()
from public.route_plan_stops stop
where stop.id = visit.route_plan_stop_id
  and stop.route_plan_id = visit.route_plan_id
  and stop.machine_id = visit.machine_id
  and (
    (stop.status = 'done' and stop.completed_at is not null and (
      visit.status is distinct from 'completed'
      or visit.completed_at is distinct from stop.completed_at
    ))
    or
    (stop.status = 'skipped' and stop.skipped_at is not null and (
      visit.status is distinct from 'skipped'
      or visit.skipped_at is distinct from stop.skipped_at
    ))
  );

-- Cover the inverse legacy mismatch as well.
update public.route_plan_stops stop
set status = case visit.status when 'completed' then 'done' else 'skipped' end,
    completed_at = case when visit.status = 'completed' then visit.completed_at else stop.completed_at end,
    skipped_at = case when visit.status = 'skipped' then visit.skipped_at else stop.skipped_at end
from public.route_machine_visits visit
where visit.route_plan_stop_id = stop.id
  and visit.route_plan_id = stop.route_plan_id
  and visit.machine_id = stop.machine_id
  and (
    (visit.status = 'completed' and visit.completed_at is not null and (
      stop.status is distinct from 'done'
      or stop.completed_at is distinct from visit.completed_at
    ))
    or
    (visit.status = 'skipped' and visit.skipped_at is not null and (
      stop.status is distinct from 'skipped'
      or stop.skipped_at is distinct from visit.skipped_at
    ))
  );

revoke all on function public.sync_route_visit_state_from_stop() from public;
revoke all on function public.sync_route_stop_state_from_visit() from public;

commit;

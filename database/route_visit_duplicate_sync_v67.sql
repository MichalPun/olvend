-- A route stop can temporarily have more than one mobile visit (for example
-- after reopening the same stop in two clients). Completing the canonical
-- visit must not try to complete every older, incomplete duplicate.
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
    where visit.id = (
      select candidate.id
      from public.route_machine_visits candidate
      where candidate.route_plan_stop_id = new.id
        and candidate.route_plan_id = new.route_plan_id
        and candidate.machine_id = new.machine_id
      order by candidate.id desc
      limit 1
    )
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
    where visit.id = (
      select candidate.id
      from public.route_machine_visits candidate
      where candidate.route_plan_stop_id = new.id
        and candidate.route_plan_id = new.route_plan_id
        and candidate.machine_id = new.machine_id
      order by candidate.id desc
      limit 1
    )
      and (
        visit.status is distinct from 'skipped'
        or visit.skipped_at is distinct from new.skipped_at
      );
  end if;

  return new;
end
$$;

commit;
notify pgrst, 'reload schema';


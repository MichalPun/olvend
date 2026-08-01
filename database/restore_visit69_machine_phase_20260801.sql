update public.route_machine_visits
set work_phase = 'machine',
    synced_at = now()
where id = 69
  and route_plan_id = 27
  and route_plan_stop_id = 126
  and machine_id = 25
  and status = 'arrived'
  and completed_at is null;

select id, route_plan_id, route_plan_stop_id, machine_id, status, work_phase, synced_at
from public.route_machine_visits
where id = 69;

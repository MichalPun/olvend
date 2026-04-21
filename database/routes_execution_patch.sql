alter table public.route_plans
  add column if not exists execution_status text not null default 'draft'
    check (execution_status in ('draft', 'assigned', 'in_progress', 'done', 'cancelled')),
  add column if not exists assigned_at timestamp with time zone,
  add column if not exists started_at timestamp with time zone,
  add column if not exists completed_at timestamp with time zone;

create index if not exists route_plans_execution_status_idx
  on public.route_plans (execution_status, planning_date desc);

alter table public.route_plan_stops
  add column if not exists arrived_at timestamp with time zone,
  add column if not exists completed_at timestamp with time zone,
  add column if not exists skipped_at timestamp with time zone;

create index if not exists route_plan_stops_status_idx
  on public.route_plan_stops (route_plan_id, status, stop_order);

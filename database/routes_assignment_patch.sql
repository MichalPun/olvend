alter table public.route_plans
  add column if not exists planned_employee_id uuid references public.employees (id) on delete set null;

create index if not exists route_plans_employee_idx
  on public.route_plans (planned_employee_id, planning_date desc);

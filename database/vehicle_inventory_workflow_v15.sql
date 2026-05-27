alter table public.inventory_audits
  drop constraint if exists inventory_audits_status_check;

alter table public.inventory_audits
  add constraint inventory_audits_status_check
  check (status in ('draft', 'assigned', 'counted', 'transfer_ready', 'evaluated', 'closed', 'cancelled'));

alter table public.inventory_audits
  add column if not exists vehicle_id bigint references public.vehicles (id) on delete set null,
  add column if not exists assigned_employee_id uuid references public.employees (id) on delete set null,
  add column if not exists instruction_id bigint references public.daily_instructions (id) on delete set null,
  add column if not exists counted_at timestamp with time zone,
  add column if not exists transfer_confirmed_at timestamp with time zone,
  add column if not exists evaluated_at timestamp with time zone,
  add column if not exists evaluation_note text;

alter table public.inventory_audit_items
  add column if not exists counted_note text,
  add column if not exists counted_at timestamp with time zone;

create index if not exists inventory_audits_vehicle_status_idx
  on public.inventory_audits (vehicle_id, status, audit_date desc);

create index if not exists inventory_audits_assigned_employee_idx
  on public.inventory_audits (assigned_employee_id, status, audit_date desc);

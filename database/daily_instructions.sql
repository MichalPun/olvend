create table if not exists public.daily_instructions (
  id bigint generated always as identity primary key,
  title text,
  message text not null,
  target_type text not null check (
    target_type in ('employee', 'role', 'company')
  ),
  target_employee_id bigint references public.employees(id) on delete cascade,
  target_role text,
  valid_from date not null,
  valid_to date,
  is_persistent boolean not null default false,
  priority text not null default 'info' check (
    priority in ('info', 'important', 'critical')
  ),
  requires_acknowledgement boolean not null default false,
  is_active boolean not null default true,
  created_by_employee_id bigint references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_instructions_target_check check (
    (target_type = 'employee' and target_employee_id is not null and target_role is null) or
    (target_type = 'role' and target_employee_id is null and target_role is not null) or
    (target_type = 'company' and target_employee_id is null and target_role is null)
  ),
  constraint daily_instructions_validity_check check (
    valid_to is null or valid_to >= valid_from
  )
);

create table if not exists public.instruction_acknowledgements (
  id bigint generated always as identity primary key,
  instruction_id bigint not null references public.daily_instructions(id) on delete cascade,
  employee_id bigint not null references public.employees(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  constraint instruction_acknowledgements_unique unique (instruction_id, employee_id)
);

create index if not exists idx_daily_instructions_active
  on public.daily_instructions (is_active, target_type, valid_from, valid_to);

create index if not exists idx_daily_instructions_target_employee
  on public.daily_instructions (target_employee_id)
  where target_type = 'employee';

create index if not exists idx_daily_instructions_target_role
  on public.daily_instructions (target_role)
  where target_type = 'role';

create index if not exists idx_instruction_ack_employee
  on public.instruction_acknowledgements (employee_id);

create index if not exists idx_instruction_ack_instruction
  on public.instruction_acknowledgements (instruction_id);

alter table public.daily_instructions enable row level security;
alter table public.instruction_acknowledgements enable row level security;

drop policy if exists "Allow read daily instructions" on public.daily_instructions;
create policy "Allow read daily instructions"
on public.daily_instructions
for select
to authenticated, anon
using (true);

drop policy if exists "Allow insert daily instructions" on public.daily_instructions;
create policy "Allow insert daily instructions"
on public.daily_instructions
for insert
to authenticated, anon
with check (true);

drop policy if exists "Allow update daily instructions" on public.daily_instructions;
create policy "Allow update daily instructions"
on public.daily_instructions
for update
to authenticated, anon
using (true)
with check (true);

drop policy if exists "Allow read instruction acknowledgements" on public.instruction_acknowledgements;
create policy "Allow read instruction acknowledgements"
on public.instruction_acknowledgements
for select
to authenticated, anon
using (true);

drop policy if exists "Allow insert instruction acknowledgements" on public.instruction_acknowledgements;
create policy "Allow insert instruction acknowledgements"
on public.instruction_acknowledgements
for insert
to authenticated, anon
with check (true);

drop policy if exists "Allow update instruction acknowledgements" on public.instruction_acknowledgements;
create policy "Allow update instruction acknowledgements"
on public.instruction_acknowledgements
for update
to authenticated, anon
using (true)
with check (true);

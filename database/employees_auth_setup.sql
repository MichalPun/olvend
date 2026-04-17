alter table public.employees
  add column if not exists auth_user_id uuid unique;

alter table public.employees
  add column if not exists created_by uuid;

alter table public.employees
  add column if not exists updated_at timestamp with time zone not null default now();

create or replace function public.set_employees_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_employees_updated_at on public.employees;

create trigger trg_employees_updated_at
before update on public.employees
for each row
execute function public.set_employees_updated_at();

alter table public.employees enable row level security;

create policy "Allow read employees"
on public.employees
for select
to authenticated, anon
using (true);

create policy "Allow insert employees"
on public.employees
for insert
to authenticated
with check (true);

create policy "Allow update employees"
on public.employees
for update
to authenticated
using (true)
with check (true);

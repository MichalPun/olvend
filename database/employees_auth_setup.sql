-- Requires the manager helper installed by the current security migrations.
-- On an incomplete installation this fails closed instead of opening access.
begin;
do $$ begin
 if to_regprocedure('public.has_manager_access()') is null
 or to_regprocedure('public.security_active_employee()') is null then
   raise exception 'Install the current security helpers before employee auth setup';
 end if;
end $$;
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

drop policy if exists "Allow read employees" on public.employees;
create policy "Allow read employees"
on public.employees
for select
to authenticated
using (public.security_active_employee() and (auth_user_id=auth.uid() or public.has_manager_access()));

drop policy if exists "Allow insert employees" on public.employees;
create policy "Allow insert employees"
on public.employees
for insert
to authenticated
with check (public.has_manager_access());

drop policy if exists "Allow update employees" on public.employees;
create policy "Allow update employees"
on public.employees
for update
to authenticated
using (public.has_manager_access())
with check (public.has_manager_access());
revoke all on public.employees from anon;
commit;

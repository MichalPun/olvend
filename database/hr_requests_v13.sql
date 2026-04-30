create table if not exists public.hr_requests (
  id bigint generated always as identity primary key,
  employee_id bigint not null references public.employees(id) on delete cascade,
  request_type text not null
    check (request_type in ('vacation', 'doctor', 'personal', 'sick', 'other')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  date_from date not null,
  date_to date not null,
  start_time time,
  end_time time,
  reason text,
  manager_note text,
  created_by_employee_id bigint references public.employees(id) on delete set null,
  approved_by_employee_id bigint references public.employees(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_requests_date_check check (date_to >= date_from),
  constraint hr_requests_time_pair_check check (
    (start_time is null and end_time is null) or
    (start_time is not null and end_time is not null and end_time > start_time)
  )
);

create index if not exists idx_hr_requests_status
  on public.hr_requests (status);

create index if not exists idx_hr_requests_employee
  on public.hr_requests (employee_id);

create index if not exists idx_hr_requests_dates
  on public.hr_requests (date_from, date_to);

create or replace function public.set_hr_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  if new.status = 'pending' then
    new.approved_at = null;
    new.approved_by_employee_id = null;
  elsif new.approved_at is null then
    new.approved_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_hr_requests_updated_at on public.hr_requests;

create trigger trg_hr_requests_updated_at
before update on public.hr_requests
for each row
execute function public.set_hr_requests_updated_at();

alter table public.hr_requests enable row level security;

drop policy if exists "Allow read hr requests" on public.hr_requests;
create policy "Allow read hr requests"
on public.hr_requests
for select
to authenticated, anon
using (true);

drop policy if exists "Allow insert hr requests" on public.hr_requests;
create policy "Allow insert hr requests"
on public.hr_requests
for insert
to authenticated, anon
with check (true);

drop policy if exists "Allow update hr requests" on public.hr_requests;
create policy "Allow update hr requests"
on public.hr_requests
for update
to authenticated, anon
using (true)
with check (true);

drop policy if exists "Allow delete hr requests" on public.hr_requests;
create policy "Allow delete hr requests"
on public.hr_requests
for delete
to authenticated, anon
using (true);

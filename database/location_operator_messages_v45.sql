create table if not exists public.location_operator_messages (
  id bigint generated always as identity primary key,
  location_id bigint not null references public.locations(id) on delete cascade,
  machine_id bigint references public.machines(id) on delete cascade,
  title text not null default 'Než začnete u automatu',
  message text not null,
  display_mode text not null default 'next_visit' check (
    display_mode in ('next_visit', 'every_visit', 'until_date')
  ),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  requires_acknowledgement boolean not null default true,
  is_active boolean not null default true,
  created_by_employee_id uuid references public.employees(id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint location_operator_messages_validity_check check (
    valid_to is null or valid_to >= valid_from
  ),
  constraint location_operator_messages_until_date_check check (
    display_mode <> 'until_date' or valid_to is not null
  )
);

create table if not exists public.location_operator_message_acknowledgements (
  id bigint generated always as identity primary key,
  message_id bigint not null references public.location_operator_messages(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  route_plan_id bigint not null references public.route_plans(id) on delete cascade,
  route_plan_stop_id bigint references public.route_plan_stops(id) on delete set null,
  acknowledged_at timestamptz not null default now(),
  constraint location_operator_message_ack_route_unique unique (
    message_id,
    employee_id,
    route_plan_id
  )
);

create index if not exists location_operator_messages_active_idx
  on public.location_operator_messages (location_id, is_active, valid_from, valid_to);

create index if not exists location_operator_messages_machine_idx
  on public.location_operator_messages (machine_id)
  where machine_id is not null;

create index if not exists location_operator_message_ack_message_idx
  on public.location_operator_message_acknowledgements (message_id, acknowledged_at desc);

create index if not exists location_operator_message_ack_employee_route_idx
  on public.location_operator_message_acknowledgements (employee_id, route_plan_id);

create or replace function public.touch_location_operator_message_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists location_operator_messages_touch_updated_at
  on public.location_operator_messages;

create trigger location_operator_messages_touch_updated_at
before update on public.location_operator_messages
for each row
execute function public.touch_location_operator_message_updated_at();

create or replace function public.close_next_visit_operator_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.location_operator_messages
  set is_active = false,
      closed_at = coalesce(closed_at, new.acknowledged_at)
  where id = new.message_id
    and display_mode = 'next_visit'
    and is_active = true;
  return new;
end;
$$;

drop trigger if exists location_operator_message_close_after_ack
  on public.location_operator_message_acknowledgements;

create trigger location_operator_message_close_after_ack
after insert on public.location_operator_message_acknowledgements
for each row
execute function public.close_next_visit_operator_message();

alter table public.location_operator_messages enable row level security;
alter table public.location_operator_message_acknowledgements enable row level security;

create or replace function public.location_message_current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.employees
  where auth_user_id = auth.uid()
    and active is distinct from false
  limit 1
$$;

create or replace function public.location_message_can_manage()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.employees
    where auth_user_id = auth.uid()
      and active is distinct from false
      and lower(coalesce(role, '')) in ('admin', 'manager')
  )
$$;

revoke all on function public.location_message_current_employee_id() from public;
revoke all on function public.location_message_can_manage() from public;
grant execute on function public.location_message_current_employee_id() to authenticated;
grant execute on function public.location_message_can_manage() to authenticated;

drop policy if exists "Allow read location operator messages" on public.location_operator_messages;
create policy "Allow read location operator messages"
on public.location_operator_messages
for select
to authenticated
using (public.location_message_current_employee_id() is not null);

drop policy if exists "Allow insert location operator messages" on public.location_operator_messages;
create policy "Allow insert location operator messages"
on public.location_operator_messages
for insert
to authenticated
with check (public.location_message_can_manage());

drop policy if exists "Allow update location operator messages" on public.location_operator_messages;
create policy "Allow update location operator messages"
on public.location_operator_messages
for update
to authenticated
using (public.location_message_can_manage())
with check (public.location_message_can_manage());

drop policy if exists "Allow read location operator message acknowledgements" on public.location_operator_message_acknowledgements;
create policy "Allow read location operator message acknowledgements"
on public.location_operator_message_acknowledgements
for select
to authenticated
using (
  employee_id = public.location_message_current_employee_id()
  or public.location_message_can_manage()
);

drop policy if exists "Allow insert location operator message acknowledgements" on public.location_operator_message_acknowledgements;
create policy "Allow insert location operator message acknowledgements"
on public.location_operator_message_acknowledgements
for insert
to authenticated
with check (
  employee_id = public.location_message_current_employee_id()
  and exists (
    select 1
    from public.route_plans plan
    where plan.id = route_plan_id
      and plan.planned_employee_id = public.location_message_current_employee_id()
  )
);

drop policy if exists "Allow update location operator message acknowledgements" on public.location_operator_message_acknowledgements;
create policy "Allow update location operator message acknowledgements"
on public.location_operator_message_acknowledgements
for update
to authenticated
using (employee_id = public.location_message_current_employee_id())
with check (employee_id = public.location_message_current_employee_id());

comment on table public.location_operator_messages is
  'Vzkazy navázané na lokalitu nebo automat, které mobil ukáže při otevření zastávky.';

comment on table public.location_operator_message_acknowledgements is
  'Potvrzení přečtení vzkazu zaměstnancem v konkrétní trase.';

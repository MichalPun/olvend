-- OLVEND v52: operátor může během směny požádat o doplnění automatu,
-- který v jeho dnešní trase chybí. Po schválení se bezpečně přidá jako
-- otevřená zastávka a mobilní přepočet ho zařadí do zbývající trasy.

create extension if not exists pgcrypto;

create table if not exists public.route_add_machine_requests (
  id uuid primary key default gen_random_uuid(),
  route_plan_id bigint not null references public.route_plans(id) on delete cascade,
  machine_id bigint not null references public.machines(id) on delete restrict,
  operator_employee_id uuid not null references public.employees(id) on delete restrict,
  approver_employee_id uuid not null references public.employees(id) on delete restrict,
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  approval_token_hash text not null,
  requested_at timestamptz not null default now(),
  email_sent_at timestamptz,
  email_delivery_id text,
  mail_error text,
  decided_at timestamptz,
  decision_note text,
  added_route_plan_stop_id bigint references public.route_plan_stops(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists route_add_machine_requests_one_pending_idx
  on public.route_add_machine_requests(route_plan_id, machine_id)
  where status = 'pending';
create unique index if not exists route_add_machine_requests_token_idx
  on public.route_add_machine_requests(approval_token_hash);
create index if not exists route_add_machine_requests_operator_idx
  on public.route_add_machine_requests(operator_employee_id, requested_at desc);

alter table public.route_add_machine_requests enable row level security;
revoke all on public.route_add_machine_requests from public, anon, authenticated;

create or replace function public.set_route_add_machine_request_updated_at_v52()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_route_add_machine_request_updated_at_v52 on public.route_add_machine_requests;
create trigger trg_route_add_machine_request_updated_at_v52
before update on public.route_add_machine_requests
for each row execute function public.set_route_add_machine_request_updated_at_v52();

create or replace function public.guard_route_plan_pending_add_v52()
returns trigger language plpgsql set search_path = public as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' and current_user not in ('postgres','supabase_admin')
     and exists(
       select 1 from public.route_add_machine_requests r
       where r.route_plan_id = new.id and r.status = 'pending'
     )
     and (new.execution_status is distinct from old.execution_status or new.completed_at is distinct from old.completed_at) then
    raise exception 'Trasu nelze uzavřít, dokud čeká žádost o přidání automatu.';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_guard_route_plan_pending_add_v52 on public.route_plans;
create trigger trg_guard_route_plan_pending_add_v52
before update on public.route_plans
for each row execute function public.guard_route_plan_pending_add_v52();

create or replace function public.get_my_route_add_machine_requests_v52(p_route_plan_id bigint)
returns table(
  id uuid,
  route_plan_id bigint,
  machine_id bigint,
  machine_name text,
  evidence_number bigint,
  location_name text,
  note text,
  status text,
  requested_at timestamptz,
  email_sent_at timestamptz,
  decided_at timestamptz,
  decision_note text,
  added_route_plan_stop_id bigint,
  approver_name text
)
language plpgsql security definer set search_path = public
as $$
declare v_employee_id uuid;
begin
  select e.id into v_employee_id
  from public.employees e
  where e.auth_user_id = auth.uid() and e.active is true;
  if v_employee_id is null then raise exception 'Aktivní zaměstnanec nebyl nalezen.'; end if;
  if not exists(
    select 1 from public.route_plans p
    where p.id = p_route_plan_id and p.planned_employee_id = v_employee_id
  ) then raise exception 'Trasa není přiřazena přihlášenému operátorovi.'; end if;

  return query
  select r.id, r.route_plan_id, r.machine_id, m.name, m.evidence_number, l.name,
         r.note, r.status, r.requested_at, r.email_sent_at, r.decided_at,
         r.decision_note, r.added_route_plan_stop_id,
         trim(concat_ws(' ', a.name, a.surname)) as approver_name
  from public.route_add_machine_requests r
  join public.machines m on m.id = r.machine_id
  left join public.locations l on l.id = m.location_id
  join public.employees a on a.id = r.approver_employee_id
  where r.route_plan_id = p_route_plan_id and r.operator_employee_id = v_employee_id
  order by r.requested_at desc;
end;
$$;
revoke all on function public.get_my_route_add_machine_requests_v52(bigint) from public, anon;
grant execute on function public.get_my_route_add_machine_requests_v52(bigint) to authenticated;

create or replace function public.cancel_my_route_add_machine_request_v52(p_request_id uuid)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare v_employee_id uuid;
begin
  select id into v_employee_id from public.employees where auth_user_id = auth.uid() and active is true;
  update public.route_add_machine_requests
  set status = 'cancelled', decided_at = now(), decision_note = 'Zrušeno operátorem.'
  where id = p_request_id and operator_employee_id = v_employee_id and status = 'pending';
  return found;
end;
$$;
revoke all on function public.cancel_my_route_add_machine_request_v52(uuid) from public, anon;
grant execute on function public.cancel_my_route_add_machine_request_v52(uuid) to authenticated;

create or replace function public.decide_route_add_machine_v52(p_token text, p_decision text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_request public.route_add_machine_requests%rowtype;
  v_plan public.route_plans%rowtype;
  v_machine public.machines%rowtype;
  v_location public.locations%rowtype;
  v_stop_id bigint;
  v_stop_order integer;
  v_title text;
  v_now timestamptz := now();
begin
  if p_decision not in ('approve','reject') then raise exception 'Neplatné rozhodnutí.'; end if;
  select * into v_request
  from public.route_add_machine_requests
  where approval_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if not found then raise exception 'Schvalovací odkaz není platný.'; end if;
  if v_request.status <> 'pending' then
    return jsonb_build_object('ok', true, 'status', v_request.status, 'already_decided', true, 'route_plan_stop_id', v_request.added_route_plan_stop_id);
  end if;
  if p_decision = 'reject' then
    update public.route_add_machine_requests
    set status = 'rejected', decided_at = v_now, decision_note = 'Žádost byla zamítnuta.'
    where id = v_request.id;
    return jsonb_build_object('ok', true, 'status', 'rejected', 'route_plan_id', v_request.route_plan_id);
  end if;

  select * into v_plan from public.route_plans where id = v_request.route_plan_id for update;
  if not found or v_plan.execution_status in ('done','cancelled') or v_plan.completed_at is not null then
    raise exception 'Trasa už je uzavřená a automat do ní nelze přidat.';
  end if;
  if exists(
    select 1 from public.route_plan_stops s
    where s.route_plan_id = v_request.route_plan_id and s.machine_id = v_request.machine_id
      and coalesce(s.status, 'pending') <> 'skipped'
  ) then raise exception 'Automat už v trase je.'; end if;

  select * into v_machine from public.machines where id = v_request.machine_id and active is true;
  if not found then raise exception 'Automat už není aktivní.'; end if;
  select * into v_location from public.locations where id = v_machine.location_id and active is true;
  if not found then raise exception 'Lokalita automatu už není aktivní.'; end if;

  select coalesce(max(stop_order), 0) + 1 into v_stop_order
  from public.route_plan_stops where route_plan_id = v_request.route_plan_id;
  v_title := concat_ws(' · ', nullif(v_location.name, ''), nullif(v_machine.name, ''));

  insert into public.route_plan_stops(
    route_plan_id, location_id, machine_id, stop_order, stop_kind, status, title,
    address_snapshot, city_snapshot, latitude, longitude, priority_snapshot,
    estimated_service_minutes, note
  ) values (
    v_request.route_plan_id, v_machine.location_id, v_machine.id, v_stop_order,
    'restock', 'planned', coalesce(nullif(v_title, ''), 'Doplnění automatu'),
    v_location.address, v_location.city, v_location.latitude, v_location.longitude,
    'normal',
    case when lower(coalesce(v_machine.machine_type, v_machine.name, '')) like any(array['%coffee%','%ká%','%kav%']) then 35 else 25 end,
    concat_ws(' · ', 'Přidáno na žádost operátora', nullif(v_request.note, ''))
  ) returning id into v_stop_id;

  update public.route_plans
  set stop_count = (select count(*) from public.route_plan_stops where route_plan_id = v_request.route_plan_id),
      estimated_service_minutes = (select coalesce(sum(s.estimated_service_minutes), 0) from public.route_plan_stops s where s.route_plan_id = v_request.route_plan_id),
      route_payload = jsonb_set(
        coalesce(route_payload, '{}'::jsonb),
        '{last_mobile_addition}',
        jsonb_build_object('request_id', v_request.id, 'machine_id', v_machine.id, 'route_plan_stop_id', v_stop_id, 'approved_at', v_now),
        true
      )
  where id = v_request.route_plan_id;

  update public.route_add_machine_requests
  set status = 'approved', decided_at = v_now, decision_note = 'Automat přidán do trasy.', added_route_plan_stop_id = v_stop_id
  where id = v_request.id;

  return jsonb_build_object('ok', true, 'status', 'approved', 'route_plan_id', v_request.route_plan_id, 'route_plan_stop_id', v_stop_id);
end;
$$;
revoke all on function public.decide_route_add_machine_v52(text,text) from public, anon, authenticated;
grant execute on function public.decide_route_add_machine_v52(text,text) to service_role;

comment on table public.route_add_machine_requests is
  'Schvalované žádosti operátorů o přidání chybějícího automatu do probíhající trasy.';

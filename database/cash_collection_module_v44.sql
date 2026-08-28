begin;

alter table public.route_machine_cash_reports
  add column if not exists variance_reason text,
  add column if not exists protocol_number text,
  add column if not exists closed_by uuid references public.employees (id) on delete set null,
  add column if not exists closed_at timestamptz;

create index if not exists route_machine_cash_reports_open_count_idx
  on public.route_machine_cash_reports (operator_collected_at desc)
  where operator_collected_confirmed is true and closed_at is null;

create index if not exists route_machine_cash_reports_protocol_idx
  on public.route_machine_cash_reports (protocol_number)
  where protocol_number is not null;

create or replace view public.cash_collection_ledger_v44
with (security_invoker = true)
as
select
  cash.id as report_id,
  cash.visit_id,
  visit.route_plan_id,
  visit.visit_date,
  visit.employee_id as operator_id,
  trim(concat_ws(' ', employee.name, employee.surname)) as operator_name,
  cash.machine_id,
  machine.name as machine_name,
  machine.evidence_number,
  machine.location_id,
  location.name as location_name,
  coalesce(nullif(cash.short_bag_code, ''), nullif(cash.operator_bag_label, ''), left(cash.bag_reference::text, 8)) as bag_code,
  cash.operator_collected_confirmed,
  cash.operator_collected_at,
  cash.expected_cash_czk,
  cash.supervisor_counted_cash_czk,
  cash.difference_cash_czk,
  cash.supervisor_counted_by,
  cash.supervisor_counted_at,
  cash.note,
  cash.variance_reason,
  cash.protocol_number,
  cash.closed_by,
  cash.closed_at,
  cash.created_at,
  cash.updated_at
from public.route_machine_cash_reports cash
join public.route_machine_visits visit on visit.id = cash.visit_id
left join public.employees employee on employee.id = visit.employee_id
left join public.machines machine on machine.id = cash.machine_id
left join public.locations location on location.id = machine.location_id;

revoke all on public.cash_collection_ledger_v44 from public, anon;
grant select on public.cash_collection_ledger_v44 to authenticated;

create or replace function public.close_cash_collection_route_v44(
  p_route_plan_id bigint,
  p_report_ids bigint[],
  p_closed_by uuid default null,
  p_protocol_number text default null
)
returns table (
  protocol_number text,
  report_count integer,
  expected_total_czk numeric,
  counted_total_czk numeric,
  difference_total_czk numeric
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_protocol text;
  v_expected numeric;
  v_counted numeric;
  v_difference numeric;
  v_count integer;
  v_actor uuid;
  v_actor_role text;
begin
  select employee.id, employee.role
  into v_actor, v_actor_role
  from public.employees employee
  where employee.auth_user_id = auth.uid()
    and employee.active is true
  limit 1;

  if v_actor is null then
    raise exception 'Uzavření svozu vyžaduje přihlášeného zaměstnance.';
  end if;

  if lower(coalesce(v_actor_role, '')) !~ '(admin|manaž|manaz|manager|vedouc|majitel)' then
    raise exception 'Svoz může uzavřít jen vedoucí, manažer, administrátor nebo majitel.';
  end if;

  if p_closed_by is not null and p_closed_by <> v_actor then
    raise exception 'Uzavírající zaměstnanec neodpovídá přihlášenému účtu.';
  end if;

  if p_route_plan_id is null or coalesce(cardinality(p_report_ids), 0) = 0 then
    raise exception 'Pro uzavření svozu vyber alespoň jeden řádek trasy.';
  end if;

  if exists (
    select 1
    from public.route_machine_cash_reports cash
    join public.route_machine_visits visit on visit.id = cash.visit_id
    where cash.id = any(p_report_ids)
      and visit.route_plan_id <> p_route_plan_id
  ) then
    raise exception 'Vybrané řádky nepatří ke stejné trase.';
  end if;

  if exists (
    select 1
    from public.route_machine_cash_reports cash
    join public.route_machine_visits visit on visit.id = cash.visit_id
    where cash.id = any(p_report_ids)
      and visit.route_plan_id = p_route_plan_id
      and (
        cash.operator_collected_confirmed is not true
        or cash.supervisor_counted_cash_czk is null
      )
  ) then
    raise exception 'Nejdřív doplň přepočítanou částku ke všem vybraným sáčkům.';
  end if;

  if exists (
    select 1
    from public.route_machine_cash_reports cash
    join public.route_machine_visits visit on visit.id = cash.visit_id
    where cash.id = any(p_report_ids)
      and visit.route_plan_id = p_route_plan_id
      and cash.expected_cash_czk is not null
      and abs(cash.supervisor_counted_cash_czk - cash.expected_cash_czk) > 10
      and nullif(trim(coalesce(cash.variance_reason, cash.note, '')), '') is null
  ) then
    raise exception 'U rozdílu nad 10 Kč je povinný důvod.';
  end if;

  select
    count(*)::integer,
    coalesce(sum(cash.expected_cash_czk), 0),
    coalesce(sum(cash.supervisor_counted_cash_czk), 0),
    coalesce(sum(cash.supervisor_counted_cash_czk - coalesce(cash.expected_cash_czk, 0)), 0)
  into v_count, v_expected, v_counted, v_difference
  from public.route_machine_cash_reports cash
  join public.route_machine_visits visit on visit.id = cash.visit_id
  where cash.id = any(p_report_ids)
    and visit.route_plan_id = p_route_plan_id;

  if v_count <> cardinality(p_report_ids) then
    raise exception 'Některé vybrané řádky svozu nebyly nalezeny.';
  end if;

  v_protocol := coalesce(
    nullif(trim(p_protocol_number), ''),
    'SC-' || to_char(current_date, 'YYYYMMDD') || '-R' || p_route_plan_id::text
  );

  update public.route_machine_cash_reports cash
  set
    protocol_number = v_protocol,
    closed_by = v_actor,
    closed_at = now()
  from public.route_machine_visits visit
  where cash.visit_id = visit.id
    and cash.id = any(p_report_ids)
    and visit.route_plan_id = p_route_plan_id;

  return query
  select v_protocol, v_count, v_expected, v_counted, v_difference;
end;
$$;

revoke all on function public.close_cash_collection_route_v44(bigint, bigint[], uuid, text) from public, anon;
grant execute on function public.close_cash_collection_route_v44(bigint, bigint[], uuid, text) to authenticated;

commit;

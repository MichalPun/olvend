begin;

create or replace function public.ensure_manual_coffee_visit_cash_v43()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_manual_mode boolean := false;
begin
  if new.machine_kind <> 'coffee' then
    return new;
  end if;

  select
    coalesce(m.sales_tracking_mode = 'manual_counters', false)
    or m.evidence_number::text in ('41', '44')
    or not exists (
      select 1
      from public.machine_external_links link
      where link.machine_id = new.machine_id
        and link.telemetry_enabled is true
    )
  into v_manual_mode
  from public.machines m
  where m.id = new.machine_id;

  if v_manual_mode then
    insert into public.route_machine_cash_reports (
      visit_id,
      machine_id,
      expected_cash_czk,
      expected_card_czk,
      expected_total_czk,
      collection_required,
      collection_threshold_czk,
      retained_for_next_visit,
      note
    ) values (
      new.id,
      new.machine_id,
      null,
      null,
      null,
      false,
      200,
      false,
      'Automat bez telemetrie: operátor musí potvrdit, že hotovost zůstala v automatu.'
    ) on conflict (visit_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_manual_coffee_visit_cash_v43 on public.route_machine_visits;
create trigger trg_manual_coffee_visit_cash_v43
after insert or update of machine_id, machine_kind
on public.route_machine_visits
for each row execute function public.ensure_manual_coffee_visit_cash_v43();

insert into public.route_machine_cash_reports (
  visit_id,
  machine_id,
  expected_cash_czk,
  expected_card_czk,
  expected_total_czk,
  collection_required,
  collection_threshold_czk,
  retained_for_next_visit,
  note
)
select
  visit.id,
  visit.machine_id,
  null,
  null,
  null,
  false,
  200,
  false,
  'Automat bez telemetrie: operátor musí potvrdit, že hotovost zůstala v automatu.'
from public.route_machine_visits visit
join public.machines machine on machine.id = visit.machine_id
where visit.machine_kind = 'coffee'
  and visit.status in ('draft', 'arrived')
  and (
    machine.sales_tracking_mode = 'manual_counters'
    or machine.evidence_number::text in ('41', '44')
    or not exists (
      select 1
      from public.machine_external_links link
      where link.machine_id = visit.machine_id
        and link.telemetry_enabled is true
    )
  )
on conflict (visit_id) do nothing;

commit;

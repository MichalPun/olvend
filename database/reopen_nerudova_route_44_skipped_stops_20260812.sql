-- Znovuotevření tří omylem přeskočených zastávek na trase Michaely Nerudové.
-- Hotové zastávky a jejich provozní záznamy zůstávají beze změny.

begin;

do $$
declare
  v_employee_id constant uuid := '7f724803-eb2e-44fc-afba-0b87b82cdbc5';
  v_stop_ids constant bigint[] := array[394, 395, 396];
  v_visit_ids constant bigint[] := array[237, 238, 239];
begin
  if not exists (
    select 1
    from public.route_plans
    where id = 44
      and planning_date = date '2026-08-12'
      and planned_employee_id = v_employee_id
      and execution_status = 'done'
  ) then
    raise exception 'Trasa #44 neodpovídá ověřené dnešní trase Michaely Nerudové.';
  end if;

  if (
    select count(*)
    from public.route_plan_stops
    where route_plan_id = 44
      and id = any(v_stop_ids)
      and status = 'skipped'
  ) <> 3 then
    raise exception 'Tři ověřené zastávky už nejsou všechny ve stavu přeskočeno.';
  end if;

  if (
    select count(*)
    from public.route_machine_visits
    where route_plan_id = 44
      and id = any(v_visit_ids)
      and route_plan_stop_id = any(v_stop_ids)
      and status = 'skipped'
  ) <> 3 then
    raise exception 'Tři ověřené návštěvy už nejsou všechny ve stavu přeskočeno.';
  end if;

  if exists (
    select 1
    from public.route_machine_visit_items
    where visit_id = any(v_visit_ids)
  ) or exists (
    select 1
    from public.route_machine_cash_reports
    where visit_id = any(v_visit_ids)
  ) or exists (
    select 1
    from public.route_machine_visit_checks
    where visit_id = any(v_visit_ids) and status = 'done'
  ) or exists (
    select 1
    from public.machine_manual_counter_readings
    where visit_id = any(v_visit_ids)
  ) then
    raise exception 'Některá přeskočená návštěva už obsahuje uloženou práci.';
  end if;

  if exists (
    select 1
    from public.inventory_audits
    where source_route_plan_id = 44
      and (
        id <> 37
        or status <> 'assigned'
        or counted_at is not null
        or evaluated_at is not null
        or closed_at is not null
        or operator_statement_at is not null
        or transfer_confirmed_at is not null
      )
  ) then
    raise exception 'Automatická inventura trasy #44 už byla rozpracována.';
  end if;

  delete from public.inventory_audits
  where id = 37
    and source_route_plan_id = 44
    and audit_origin = 'post_route_exception'
    and status = 'assigned'
    and counted_at is null
    and evaluated_at is null
    and closed_at is null;

  update public.route_machine_visits
  set
    status = 'draft',
    arrived_at = null,
    completed_at = null,
    skipped_at = null,
    skip_reason = null,
    operator_note = null,
    synced_at = now(),
    updated_at = now()
  where route_plan_id = 44
    and id = any(v_visit_ids);

  update public.route_plan_stops
  set
    status = 'planned',
    arrived_at = null,
    completed_at = null,
    skipped_at = null
  where route_plan_id = 44
    and id = any(v_stop_ids);

  update public.route_plans
  set
    execution_status = 'in_progress',
    completed_at = null,
    updated_at = now()
  where id = 44;

  if (select count(*) from public.route_plan_stops where id = any(v_stop_ids) and status = 'planned') <> 3
     or (select count(*) from public.route_machine_visits where id = any(v_visit_ids) and status = 'draft') <> 3
     or exists (select 1 from public.inventory_audits where source_route_plan_id = 44)
     or not exists (select 1 from public.route_plans where id = 44 and execution_status = 'in_progress' and completed_at is null) then
    raise exception 'Trasu #44 se nepodařilo znovu otevřít kompletně.';
  end if;

  raise notice 'Trasa #44 byla znovu otevřena, tři zastávky čekají na dokončení.';
end
$$;

commit;

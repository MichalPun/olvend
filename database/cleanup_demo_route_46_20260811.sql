-- Odstranění ukázkové trasy Michala Punčocháře z 11. 8. 2026.
-- Trasa neobsahovala žádné reálné doplnění, odpis ani skladový pohyb.

begin;

do $$
declare
  v_route public.route_plans%rowtype;
  v_visit_ids bigint[];
begin
  select *
    into v_route
  from public.route_plans
  where id = 46
  for update;

  if not found then
    raise notice 'Ukázková trasa #46 už neexistuje.';
    return;
  end if;

  if v_route.planning_date <> date '2026-08-11'
     or v_route.planned_employee_id <> 'abad3293-29a0-4668-97c5-0c6fa08ece0f'::uuid
     or v_route.stop_count <> 2 then
    raise exception 'Trasa #46 neodpovídá ověřené ukázkové trase.';
  end if;

  select coalesce(array_agg(id order by id), '{}'::bigint[])
    into v_visit_ids
  from public.route_machine_visits
  where route_plan_id = 46;

  if exists (
    select 1
    from public.route_machine_visit_items
    where visit_id = any(v_visit_ids)
      and (
        coalesce(actual_add_quantity, 0) <> 0
        or coalesce(removed_quantity, 0) <> 0
      )
  ) then
    raise exception 'Trasa #46 obsahuje skutečné doplnění nebo odpis.';
  end if;

  if exists (
    select 1
    from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and exists (
        select 1
        from unnest(v_visit_ids) visit_id
        where movement.reference_id like ('route_visit_' || visit_id || '_%')
      )
  ) then
    raise exception 'Trasa #46 obsahuje skladové pohyby.';
  end if;

  if exists (
    select 1
    from public.route_vehicle_waste_items
    where route_plan_id = 46
  ) or exists (
    select 1
    from public.inventory_audits
    where source_route_plan_id = 46
  ) then
    raise exception 'Trasa #46 má navázaný odpis nebo inventuru.';
  end if;

  delete from public.route_machine_visits
  where route_plan_id = 46;

  delete from public.route_plans
  where id = 46;

  if exists (select 1 from public.route_plans where id = 46)
     or exists (select 1 from public.route_machine_visits where id = any(v_visit_ids)) then
    raise exception 'Ukázkovou trasu #46 se nepodařilo odstranit kompletně.';
  end if;

  raise notice 'Ukázková trasa #46 a její návštěvy byly odstraněny.';
end
$$;

commit;

begin;

select set_config(
  'request.jwt.claim.sub',
  (select auth_user_id::text from public.employees where active is true and auth_user_id is not null order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_employee uuid := public.current_employee_id();
  v_location bigint;
  v_machine bigint;
  v_slot bigint;
  v_old_price numeric;
  v_new_price numeric;
  v_route bigint;
  v_stop bigint;
  v_control_machine bigint;
  v_result jsonb;
  v_route_plan_count bigint;
  v_route_stop_count bigint;
begin
  select m.location_id, m.id, s.id, s.price_czk
  into v_location, v_machine, v_slot, v_old_price
  from public.machine_planogram_slots s
  join public.machines m on m.id = s.machine_id and m.active is true
  join public.locations l on l.id = m.location_id and l.active is true
  where s.active is true
  order by s.id
  limit 1;

  if v_slot is null then raise exception 'Chybí aktivní pozice pro rollback test.'; end if;
  v_new_price := coalesce(v_old_price, 0) + 1;
  select count(*) into v_route_plan_count from public.route_plans;
  select count(*) into v_route_stop_count from public.route_plan_stops;

  v_route := public.create_control_route_v55(jsonb_build_object(
    'name', 'TEST control_adjustments_v56 rollback',
    'control_type', 'regular',
    'planned_date', current_date,
    'planned_start_time', '08:00',
    'assigned_employee_id', v_employee,
    'publish', true,
    'checklist_config', jsonb_build_object('adjust_price', true),
    'rule_config', '{}'::jsonb,
    'stops', jsonb_build_array(jsonb_build_object(
      'location_id', v_location,
      'stop_order', 1,
      'machines', jsonb_build_array(jsonb_build_object('machine_id', v_machine))
    ))
  ));
  perform public.start_control_route_v55(v_route);

  select id into v_stop from public.control_route_stops where control_route_id = v_route;
  update public.control_route_stops set status = 'in_progress', started_at = now() where id = v_stop;
  select id into v_control_machine from public.control_route_machines where control_route_stop_id = v_stop;

  v_result := public.apply_control_machine_adjustment_v56(
    v_control_machine,
    'food_slot',
    v_slot,
    'price',
    jsonb_build_object('price_czk', v_new_price),
    'Automatický rollback test'
  );

  if v_result->>'status' <> 'applied' then
    raise exception 'Změna nebyla označena jako applied.';
  end if;
  if (select price_czk from public.machine_planogram_slots where id = v_slot) is distinct from v_new_price then
    raise exception 'Cena se nepropsala do aktivního plánogramu.';
  end if;
  if (select customer_price_czk from public.machine_planogram_slots where id = v_slot) is distinct from v_new_price then
    raise exception 'Cena se nepropsala jako skutečná cena automatu.';
  end if;
  if not exists (
    select 1 from public.control_machine_adjustments
    where control_route_id = v_route and target_kind = 'food_slot'
      and target_record_id = v_slot and adjustment_type = 'price'
      and status = 'applied' and applied_at is not null
  ) then
    raise exception 'Chybí auditní záznam provedené změny.';
  end if;
  if (select count(*) from public.route_plans) <> v_route_plan_count then
    raise exception 'Změna z kontroly ovlivnila počet běžných tras.';
  end if;
  if (select count(*) from public.route_plan_stops) <> v_route_stop_count then
    raise exception 'Změna z kontroly ovlivnila počet zastávek běžných tras.';
  end if;
end;
$$;

rollback;

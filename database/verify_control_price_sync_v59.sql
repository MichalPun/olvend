begin;

select set_config(
  'request.jwt.claim.sub',
  (
    select auth_user_id::text
    from public.employees
    where active is true
      and auth_user_id is not null
      and lower(coalesce(role, '')) in ('admin', 'manager')
    order by created_at
    limit 1
  ),
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
  v_slot_code text;
  v_category text;
  v_old_price numeric;
  v_old_dex numeric;
  v_manual_price numeric;
  v_bulk_price numeric;
  v_route bigint;
  v_stop bigint;
  v_control_machine bigint;
  v_approval jsonb;
  v_batch uuid;
  v_item uuid;
  v_result jsonb;
begin
  if v_employee is null or not public.has_manager_access() then
    raise exception 'Pro test chybí aktivní vedoucí účet.';
  end if;

  select
    m.location_id,
    m.id,
    s.id,
    s.slot_code,
    coalesce(s.customer_price_czk, s.price_czk, 0),
    s.dex_price_czk,
    case
      when p.product_category in ('beverage_ready', 'snack_ready', 'food_ready')
        then p.product_category
      else 'other'
    end
  into
    v_location, v_machine, v_slot, v_slot_code, v_old_price, v_old_dex,
    v_category
  from public.machine_planogram_slots s
  join public.machines m on m.id = s.machine_id and m.active is true
  join public.locations l on l.id = m.location_id and l.active is true
  left join public.products p on p.sku = s.product_sku
  where s.active is true
    and not exists (
      select 1
      from public.machine_price_change_items i
      where i.planogram_slot_id = s.id and i.status = 'pending'
    )
  order by s.id
  limit 1;

  if v_slot is null then
    raise exception 'Chybí volná aktivní pozice pro rollback test.';
  end if;

  v_manual_price := v_old_price + 1;
  v_bulk_price := v_old_price + 2;

  v_route := public.create_control_route_v55(jsonb_build_object(
    'name', 'TEST control_price_sync_v59 rollback',
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
  update public.control_route_stops
  set status = 'in_progress', started_at = now()
  where id = v_stop;
  select id into v_control_machine
  from public.control_route_machines
  where control_route_stop_id = v_stop;

  v_approval := public.approve_machine_price_change_v55(
    v_machine,
    jsonb_build_array(jsonb_build_object(
      'target_type', 'food_slot',
      'target_id', v_slot,
      'new_price_czk', v_manual_price,
      'recommended_price_czk', v_manual_price
    )),
    jsonb_build_array(jsonb_build_object(
      'category_key', v_category,
      'minimum_margin_percent', 0,
      'rounding_step_czk', 1
    )),
    'Rollback test ručního spárování'
  );
  v_batch := (v_approval->>'batch_id')::uuid;
  select id into v_item
  from public.machine_price_change_items
  where batch_id = v_batch;

  v_result := public.apply_control_machine_adjustment_v56(
    v_control_machine,
    'food_slot',
    v_slot,
    'price',
    jsonb_build_object('price_czk', v_manual_price),
    'Rollback test ruční ceny'
  );

  if v_result->>'status' <> 'applied'
     or (select status from public.machine_price_change_items where id = v_item) <> 'applied'
     or (select status from public.machine_price_change_batches where id = v_batch) <> 'completed' then
    raise exception 'Ruční cena se nepropsala a neuzavřela připravenou cenovou sadu.';
  end if;
  if (select dex_price_czk from public.machine_planogram_slots where id = v_slot)
     is distinct from v_old_dex then
    raise exception 'Ruční změna nesmí předstírat novou cenu z telemetrie.';
  end if;

  v_approval := public.approve_machine_price_change_v55(
    v_machine,
    jsonb_build_array(jsonb_build_object(
      'target_type', 'food_slot',
      'target_id', v_slot,
      'new_price_czk', v_bulk_price,
      'recommended_price_czk', v_bulk_price
    )),
    jsonb_build_array(jsonb_build_object(
      'category_key', v_category,
      'minimum_margin_percent', 0,
      'rounding_step_czk', 1
    )),
    'Rollback test atomického potvrzení'
  );
  v_batch := (v_approval->>'batch_id')::uuid;
  select id into v_item
  from public.machine_price_change_items
  where batch_id = v_batch;

  v_result := public.apply_all_control_price_changes_v59(v_control_machine);

  if (v_result->>'applied_count')::integer <> 1
     or (select status from public.machine_price_change_items where id = v_item) <> 'applied'
     or (select status from public.machine_price_change_batches where id = v_batch) <> 'completed'
     or (select customer_price_czk from public.machine_planogram_slots where id = v_slot)
        is distinct from v_bulk_price then
    raise exception 'Atomické hromadné potvrzení neuložilo celou cenovou sadu.';
  end if;
  if (select dex_price_czk from public.machine_planogram_slots where id = v_slot)
     is distinct from v_old_dex then
    raise exception 'Hromadná změna nesmí předstírat novou cenu z telemetrie.';
  end if;
end;
$$;

rollback;

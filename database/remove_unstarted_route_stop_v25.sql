create or replace function public.remove_unstarted_route_stop(
  p_route_plan_id bigint,
  p_route_plan_stop_id bigint,
  p_estimated_distance_km numeric,
  p_estimated_drive_minutes integer,
  p_estimated_service_minutes integer,
  p_optimization_provider text,
  p_provider_status text,
  p_route_payload jsonb,
  p_end_latitude numeric,
  p_end_longitude numeric
)
returns table (remaining_stop_count integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.route_plans%rowtype;
  v_stop public.route_plan_stops%rowtype;
  v_remaining integer;
begin
  if auth.uid() is null or not exists (
    select 1
    from public.employees
    where auth_user_id = auth.uid()
      and active is not false
      and (
        lower(coalesce(role, '')) like '%admin%'
        or lower(coalesce(role, '')) like '%manaž%'
        or lower(coalesce(role, '')) like '%manaz%'
        or lower(coalesce(role, '')) like '%manager%'
        or lower(coalesce(role, '')) like '%vedouc%'
        or lower(coalesce(role, '')) like '%majitel%'
      )
  ) then
    raise exception 'Zastávky může z trasy odebírat pouze vedení.';
  end if;

  select *
  into v_plan
  from public.route_plans
  where id = p_route_plan_id
  for update;

  if not found then
    raise exception 'Trasa nebyla nalezena.';
  end if;

  if v_plan.execution_status not in ('draft', 'assigned') or v_plan.started_at is not null then
    raise exception 'Trasa už začala a zastávku nelze odebrat.';
  end if;

  select *
  into v_stop
  from public.route_plan_stops
  where id = p_route_plan_stop_id
    and route_plan_id = p_route_plan_id
  for update;

  if not found then
    raise exception 'Zastávka nebyla nalezena.';
  end if;

  if v_stop.status <> 'planned'
    or v_stop.arrived_at is not null
    or v_stop.completed_at is not null
    or v_stop.skipped_at is not null then
    raise exception 'Zastávka už začala nebo byla uzavřena.';
  end if;

  if exists (
    select 1
    from public.route_machine_visits
    where route_plan_stop_id = p_route_plan_stop_id
  ) then
    raise exception 'K zastávce už existuje mobilní záznam.';
  end if;

  delete from public.route_cash_reports
  where route_plan_stop_id = p_route_plan_stop_id;

  delete from public.route_plan_stops
  where id = p_route_plan_stop_id
    and route_plan_id = p_route_plan_id;

  update public.route_plan_stops
  set stop_order = stop_order + 100000
  where route_plan_id = p_route_plan_id
    and stop_order > v_stop.stop_order;

  update public.route_plan_stops
  set stop_order = stop_order - 100001
  where route_plan_id = p_route_plan_id
    and stop_order > 100000;

  select count(*)::integer
  into v_remaining
  from public.route_plan_stops
  where route_plan_id = p_route_plan_id;

  update public.route_plans
  set stop_count = v_remaining,
      estimated_distance_km = greatest(coalesce(p_estimated_distance_km, 0), 0),
      estimated_drive_minutes = greatest(coalesce(p_estimated_drive_minutes, 0), 0),
      estimated_service_minutes = greatest(coalesce(p_estimated_service_minutes, 0), 0),
      optimization_provider = coalesce(nullif(p_optimization_provider, ''), optimization_provider),
      provider_status = coalesce(nullif(p_provider_status, ''), provider_status),
      route_payload = coalesce(p_route_payload, route_payload),
      end_latitude = p_end_latitude,
      end_longitude = p_end_longitude
  where id = p_route_plan_id;

  return query select v_remaining;
end;
$$;

revoke all on function public.remove_unstarted_route_stop(bigint, bigint, numeric, integer, integer, text, text, jsonb, numeric, numeric) from public;
grant execute on function public.remove_unstarted_route_stop(bigint, bigint, numeric, integer, integer, text, text, jsonb, numeric, numeric) to authenticated;

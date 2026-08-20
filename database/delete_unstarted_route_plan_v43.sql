-- OLVEND v43: bezpečné odstranění trasy, která ještě nezačala.
create or replace function public.delete_unstarted_route_plan_v43(p_route_plan_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.route_plans%rowtype;
  v_title text;
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
    raise exception 'Trasu může smazat pouze vedení.';
  end if;

  select *
  into v_plan
  from public.route_plans
  where id = p_route_plan_id
  for update;

  if not found then
    raise exception 'Trasa nebyla nalezena.';
  end if;

  v_title := coalesce(v_plan.title, 'Trasa #' || v_plan.id::text);

  if coalesce(v_plan.execution_status, 'draft') not in ('draft', 'assigned')
    or v_plan.started_at is not null
    or v_plan.completed_at is not null then
    raise exception 'Trasa už začala nebo byla uzavřena. Lze ji pouze zrušit.';
  end if;

  if exists (
    select 1
    from public.route_plan_stops
    where route_plan_id = p_route_plan_id
      and (
        status <> 'planned'
        or arrived_at is not null
        or completed_at is not null
        or skipped_at is not null
      )
  ) then
    raise exception 'Na trase už proběhla práce. Lze ji pouze zrušit.';
  end if;

  if exists (
    select 1
    from public.route_machine_visits
    where route_plan_id = p_route_plan_id
      and (
        status <> 'draft'
        or arrived_at is not null
        or completed_at is not null
        or skipped_at is not null
      )
  ) then
    raise exception 'K trase už existuje mobilní průběh. Lze ji pouze zrušit.';
  end if;

  if exists (
    select 1
    from public.mobile_stock_requests
    where route_plan_id = p_route_plan_id
      and status in ('picking', 'ready', 'confirmed')
  ) then
    raise exception 'Pro trasu už probíhá nebo proběhla nakládka. Lze ji pouze zrušit.';
  end if;

  if exists (
    select 1
    from public.loading_sessions
    where route_plan_id = p_route_plan_id
  ) then
    raise exception 'K trase už existuje nakládací relace. Lze ji pouze zrušit.';
  end if;

  delete from public.route_machine_visits
  where route_plan_id = p_route_plan_id
    and status = 'draft';

  update public.mobile_stock_requests
  set status = 'cancelled',
      note = concat_ws(' · ', nullif(note, ''), 'Automaticky zrušeno při smazání nezačaté trasy #' || p_route_plan_id::text)
  where route_plan_id = p_route_plan_id
    and status in ('draft', 'requested');

  delete from public.route_plans
  where id = p_route_plan_id;

  return jsonb_build_object(
    'ok', true,
    'route_plan_id', p_route_plan_id,
    'title', v_title
  );
end;
$$;

revoke all on function public.delete_unstarted_route_plan_v43(bigint) from public, anon;
grant execute on function public.delete_unstarted_route_plan_v43(bigint) to authenticated;

comment on function public.delete_unstarted_route_plan_v43(bigint) is
  'Bezpečně smaže pouze nezačatou trasu bez reálného průběhu a potvrzené nakládky.';

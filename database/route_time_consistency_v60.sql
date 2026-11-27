-- OLVEND v60: ruční pořadí trasy nesmí přepsat stará kopie v mobilu.
-- Přepočet smí doplnit nové Google časy, ale při aktivním ručním pořadí musí
-- poslat otevřené zastávky přesně ve stejném pořadí jako databáze.
create or replace function public.apply_mobile_route_recalculation_v39(
  p_route_plan_id bigint,
  p_ordered_stop_ids bigint[],
  p_trigger_key text,
  p_metadata jsonb
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_employee_id uuid;
  v_open_ids bigint[];
  v_closed_ids bigint[];
  v_route_payload jsonb;
  v_id bigint;
  v_order integer := 0;
begin
  select id into v_employee_id from public.employees where auth_user_id = auth.uid() and active is true;
  if v_employee_id is null then raise exception 'Aktivní zaměstnanec nebyl nalezen.'; end if;

  select coalesce(route_payload,'{}'::jsonb) into v_route_payload
  from public.route_plans
  where id = p_route_plan_id and planned_employee_id = v_employee_id
  for update;
  if not found then raise exception 'Trasa není přiřazena přihlášenému operátorovi.'; end if;
  if exists(select 1 from public.route_stop_skip_requests where route_plan_id = p_route_plan_id and status = 'pending') then
    raise exception 'Trasa čeká na schválení nejeté zastávky.';
  end if;

  select coalesce(array_agg(id order by stop_order), '{}'::bigint[]) into v_closed_ids
  from public.route_plan_stops
  where route_plan_id = p_route_plan_id
    and (status in ('done','completed','skipped') or completed_at is not null or skipped_at is not null);
  select coalesce(array_agg(id order by stop_order), '{}'::bigint[]) into v_open_ids
  from public.route_plan_stops
  where route_plan_id = p_route_plan_id
    and not (status in ('done','completed','skipped') or completed_at is not null or skipped_at is not null);

  if cardinality(v_open_ids) <> cardinality(coalesce(p_ordered_stop_ids, '{}'::bigint[]))
     or exists(select 1 from unnest(v_open_ids) x where not (x = any(p_ordered_stop_ids)))
     or exists(select 1 from unnest(p_ordered_stop_ids) x where not (x = any(v_open_ids))) then
    raise exception 'Pořadí neodpovídá aktuálně otevřeným zastávkám.';
  end if;

  if coalesce((v_route_payload->>'manually_reordered')::boolean,false)
     and p_ordered_stop_ids is distinct from v_open_ids then
    raise exception 'Pořadí trasy změnilo vedení. Obnov trasu; starý mobilní přepočet jej nesmí přepsat.';
  end if;

  update public.route_plan_stops set stop_order = stop_order + 1000000 where route_plan_id = p_route_plan_id;
  foreach v_id in array v_closed_ids loop
    v_order := v_order + 1;
    update public.route_plan_stops set stop_order = v_order where id = v_id;
  end loop;
  foreach v_id in array p_ordered_stop_ids loop
    v_order := v_order + 1;
    update public.route_plan_stops set stop_order = v_order where id = v_id;
  end loop;

  update public.route_plans
  set route_payload = jsonb_set(coalesce(route_payload, '{}'::jsonb), '{mobile_recalculation}', coalesce(p_metadata, '{}'::jsonb), true)
  where id = p_route_plan_id;

  insert into public.route_mobile_recalculations(
    route_plan_id, employee_id, trigger_key, previous_stop_ids, ordered_stop_ids, provider,
    baseline_distance_meters, distance_meters, baseline_duration_seconds, duration_seconds, reason, payload
  ) values (
    p_route_plan_id, v_employee_id, p_trigger_key, v_open_ids, p_ordered_stop_ids,
    coalesce(p_metadata->>'provider','google_routes'),
    nullif(p_metadata->>'baseline_distance_meters','')::integer,
    nullif(p_metadata->>'distance_meters','')::integer,
    nullif(p_metadata->>'baseline_duration_seconds','')::integer,
    nullif(p_metadata->>'duration_seconds','')::integer,
    p_metadata->>'reason', coalesce(p_metadata, '{}'::jsonb)
  ) on conflict(route_plan_id, trigger_key) do nothing;

  return jsonb_build_object('ok', true, 'ordered_stop_ids', p_ordered_stop_ids);
end;
$$;

revoke all on function public.apply_mobile_route_recalculation_v39(bigint,bigint[],text,jsonb) from public, anon;
grant execute on function public.apply_mobile_route_recalculation_v39(bigint,bigint[],text,jsonb) to authenticated;

comment on function public.apply_mobile_route_recalculation_v39(bigint,bigint[],text,jsonb)
is 'Průběžně ukládá Google ETA; ručně změněné pořadí smí pouze zachovat, nikdy přepsat ze staré mobilní kopie.';

notify pgrst, 'reload schema';

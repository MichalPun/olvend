begin;

update public.locations
set
  service_window = 'Po-Pá 6:00 - 17:00',
  route_access_status = 'confirmed',
  route_access_hours = jsonb_build_object(
    'default', jsonb_build_object(
      'mo', jsonb_build_array(jsonb_build_array('06:00', '17:00')),
      'tu', jsonb_build_array(jsonb_build_array('06:00', '17:00')),
      'we', jsonb_build_array(jsonb_build_array('06:00', '17:00')),
      'th', jsonb_build_array(jsonb_build_array('06:00', '17:00')),
      'fr', jsonb_build_array(jsonb_build_array('06:00', '17:00'))
    )
  )
where id in (4, 5)
  and name in ('Střední škola hl. budova', 'Střední škola vedl.budova');

-- Trasa 83 už po opravě přístupu nečeká 102 minut na druhý interval.
update public.route_plans
set route_payload = jsonb_set(
  coalesce(route_payload, '{}'::jsonb),
  '{route_time_budget}',
  coalesce(route_payload -> 'route_time_budget', '{}'::jsonb) || jsonb_build_object(
    'verdict', 'ok',
    'maximum_hours', 8,
    'maximum_minutes', 480,
    'remaining_minutes', 37,
    'preparation_minutes', 15,
    'food_service_minutes', 17,
    'coffee_service_minutes', 17,
    'estimated_total_minutes', 443
  ),
  true
)
where id = 83
  and planning_date = date '2026-09-02';

do $$
declare
  v_bad_count integer;
begin
  select count(*) into v_bad_count
  from public.locations
  where id in (4, 5)
    and (
      service_window <> 'Po-Pá 6:00 - 17:00'
      or route_access_status <> 'confirmed'
      or route_access_hours #>> '{default,we,0,0}' <> '06:00'
      or route_access_hours #>> '{default,we,0,1}' <> '17:00'
      or route_access_hours ? 'periods'
    );
  if v_bad_count <> 0 then
    raise exception 'Provozní doba školy se neuložila jednotně.';
  end if;
end;
$$;

commit;

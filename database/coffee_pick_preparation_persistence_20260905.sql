-- Trvale ulozi rucni rozhodnuti kavoveho picklistu, vcetne nuloveho doplneni.
-- Soucasne opravi rozpracovanou navstevu #610 EV125 podle potvrzene skutecnosti:
-- pouze Matcha Z6 = 2 baleni, vsechny ostatni zasobniky bez doplneni.

begin;

alter table public.route_machine_visits
  add column if not exists coffee_preparation jsonb not null default '{}'::jsonb;

comment on column public.route_machine_visits.coffee_preparation is
  'Serverovy snapshot rozhodnuti kavoveho picklistu a rozpracovaneho doplneni; uchovava i volbu 0 / nic nedoplnuji.';

do $$
declare
  v_machine_id bigint;
  v_container_count integer;
  v_preparation jsonb;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number = 125
    and brand = 'Jetinno'
    and model = 'JL300';

  if v_machine_id is null then
    raise exception 'Jetinno EV125 nebylo nalezeno.';
  end if;

  if not exists (
    select 1 from public.route_machine_visits
    where id = 610
      and machine_id = v_machine_id
      and status = 'arrived'
      and work_phase = 'machine'
      and completed_at is null
  ) then
    raise exception 'Rozpracovana navsteva #610 EV125 neni v ocekavanem stavu.';
  end if;

  select count(*), jsonb_build_object(
    'version', 1,
    'phase', 'machine',
    'containers', jsonb_object_agg(
      c.id::text,
      jsonb_build_object(
        'packages', case when c.container_code = 'Z6' then 2 else 0 end,
        'packagesManuallyAdjusted', true,
        'picked', true,
        'accepted', true,
        'movedPackages', case when c.container_code = 'Z6' then 2 else 0 end,
        'stockMismatch', false
      )
    ),
    'savedAt', now()
  )
  into v_container_count, v_preparation
  from public.machine_coffee_containers c
  where c.machine_id = v_machine_id
    and c.active = true;

  if v_container_count <> 8 then
    raise exception 'EV125 ma mit 8 aktivnich zasobniku, nalezeno %.', v_container_count;
  end if;

  update public.route_machine_visits
  set coffee_preparation = v_preparation,
      synced_at = now(),
      updated_at = now()
  where id = 610
    and machine_id = v_machine_id;
end
$$;

commit;

notify pgrst, 'reload schema';

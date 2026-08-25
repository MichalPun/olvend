do $$
declare
  v_machine_id bigint := 42;
  v_conflicting_machine_id bigint;
begin
  select machine_id
  into v_conflicting_machine_id
  from public.machine_external_links
  where provider in ('IMA', 'GP')
    and external_machine_id = '629426'
    and machine_id <> v_machine_id
  limit 1;

  if v_conflicting_machine_id is not null then
    raise exception 'TID 629426 je již přiřazen automatu %.', v_conflicting_machine_id;
  end if;

  if not exists (
    select 1
    from public.machines
    where id = v_machine_id
      and evidence_number = 51
      and active = true
  ) then
    raise exception 'Aktivní automat EV 51 / DB 42 nebyl nalezen.';
  end if;

  insert into public.machine_external_links (
    machine_id, provider, external_machine_id, telemetry_enabled, note
  )
  values
    (v_machine_id, 'IMA', '629426', true, 'TID 629426 · EV 51 · bazén Hrušovany nad Jevišovkou.'),
    (v_machine_id, 'GP', '629426', true, 'TID 629426 · EV 51 · bazén Hrušovany nad Jevišovkou.')
  on conflict (provider, external_machine_id) do update
  set machine_id = excluded.machine_id,
      telemetry_enabled = true,
      note = excluded.note,
      updated_at = now();

  update public.machines
  set sales_tracking_mode = 'telemetry',
      note = trim(regexp_replace(
        coalesce(note, ''),
        ';?\\s*bez telemetrického terminálu\\.?',
        '',
        'gi'
      )),
      updated_at = now()
  where id = v_machine_id;
end $$;

select
  m.id,
  m.evidence_number,
  m.name,
  m.sales_tracking_mode,
  m.stock_initialized_at,
  l.provider,
  l.external_machine_id,
  l.telemetry_enabled
from public.machines m
join public.machine_external_links l on l.machine_id = m.id
where m.id = 42
order by l.provider;

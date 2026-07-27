do $$
declare
  v_machine_id bigint;
begin
  select id into v_machine_id
  from public.machines
  where evidence_number = 67
  limit 1;

  if v_machine_id is null then
    raise exception 'Machine evidence 67 was not found.';
  end if;

  update public.machine_external_links
  set
    machine_id = v_machine_id,
    telemetry_enabled = true,
    note = 'Oprava 2026-07-27: TID 596506 patri automatu 67 / Jamne - SWR, ne automatu 42.',
    updated_at = now()
  where provider in ('IMA', 'GP')
    and external_machine_id = '596506';

  insert into public.machine_external_links (machine_id, provider, external_machine_id, telemetry_enabled, note)
  values
    (v_machine_id, 'IMA', '596506', true, 'TID 596506 pro automat 67 / Jamne - SWR.'),
    (v_machine_id, 'GP', '596506', true, 'TID 596506 pro automat 67 / Jamne - SWR.')
  on conflict (provider, external_machine_id) do update
  set
    machine_id = excluded.machine_id,
    telemetry_enabled = excluded.telemetry_enabled,
    note = excluded.note,
    updated_at = now();
end $$;

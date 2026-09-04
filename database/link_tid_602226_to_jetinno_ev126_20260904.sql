-- Presun TID 602226 z odstaveneho EV27 na Jetinno JL300 EV126.
-- Historicke prodeje zustavaji na EV27; EV126 zacina bez citacu a prvni DEX je baseline.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_count integer;
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number=27 and location_id is null;

  select id into strict v_target_machine_id
  from public.machines
  where evidence_number=126 and name='Jetinno JL300' and brand='Jetinno'
    and model='JL300' and location_id=60 and status='ok' and active=true;

  if (select count(*) from public.machine_external_links
      where machine_id=v_source_machine_id and external_machine_id='602226'
        and provider in ('IMA','GP') and telemetry_enabled=false)<>2 then
    raise exception 'Na EV27 nebyly nalezeny obe deaktivovane vazby IMA/GP pro TID 602226.';
  end if;

  if exists (select 1 from public.machine_external_links where machine_id=v_target_machine_id)
     or exists (select 1 from public.machine_telemetry_state where machine_id=v_target_machine_id)
     or exists (select 1 from public.telemetry_planogram_counters where machine_id=v_target_machine_id)
     or exists (select 1 from public.telemetry_sales_events where machine_id=v_target_machine_id) then
    raise exception 'EV126 uz obsahuje telemetrickou vazbu, stav, citace nebo prodeje.';
  end if;

  update public.machine_external_links
  set machine_id=v_target_machine_id,
      telemetry_enabled=true,
      note='TID 602226 · terminál převeden z odstaveného EV27 na Jetinno JL300 EV126 na Vitaru dne 4. 9. 2026. První nový DEX vytvoří výchozí čítače EV126.',
      updated_at=now()
  where machine_id=v_source_machine_id and external_machine_id='602226'
    and provider in ('IMA','GP') and telemetry_enabled=false;

  get diagnostics v_count=row_count;
  if v_count<>2 then
    raise exception 'Presun TID 602226 selhal: ocekavany 2 vazby, upraveno %.',v_count;
  end if;

  update public.machines
  set sales_tracking_mode='telemetry',
      note=concat_ws(' ',nullif(note,''),'· TID 602226 přiřazen 4. 9. 2026; IMA/GP aktivní, čeká se na první nový DEX.'),
      updated_at=now()
  where id=v_target_machine_id;

  update public.machines
  set note=concat_ws(' ',nullif(note,''),'· TID 602226 převeden na Jetinno EV126 dne 4. 9. 2026.'),
      updated_at=now()
  where id=v_source_machine_id;

  if (select count(*) from public.machine_external_links
      where machine_id=v_target_machine_id and external_machine_id='602226'
        and provider in ('IMA','GP') and telemetry_enabled=true)<>2 then
    raise exception 'Zaverecna kontrola: EV126 nema obe aktivni vazby TID 602226.';
  end if;

  if exists (select 1 from public.machine_external_links
             where machine_id=v_source_machine_id and external_machine_id='602226') then
    raise exception 'Zaverecna kontrola: na EV27 zustala vazba TID 602226.';
  end if;
end $$;

commit;

select m.evidence_number,m.name,l.provider,l.external_machine_id,l.telemetry_enabled,l.note
from public.machines m
join public.machine_external_links l on l.machine_id=m.id
where m.evidence_number=126 and l.external_machine_id='602226'
order by l.provider;

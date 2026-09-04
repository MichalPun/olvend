-- LEI 600 Touch EV80: stazeni z lokality Vitar do dilny/skladu Blucina.
-- TID 592150 se deaktivuje, ale vazby i historie zustavaji zachovane.
-- Evidovany obsah stroje zustava na skladove karte automatu EV80.

begin;

do $$
declare
  v_machine_id bigint;
  v_from_location_id bigint;
  v_machine_stock_location_id bigint;
  v_link_count integer;
begin
  select id,location_id
  into strict v_machine_id,v_from_location_id
  from public.machines
  where evidence_number=80
    and name='LEI 600 Touch'
    and brand='Bianchi'
    and location_id=60
    and status='ok'
    and active=true;

  if not exists (select 1 from public.locations where id=60 and name='Vitar' and active=true) then
    raise exception 'Zdrojova lokalita Vitar ID60 nebyla nalezena.';
  end if;

  select count(*) into v_link_count
  from public.machine_external_links
  where machine_id=v_machine_id
    and external_machine_id='592150'
    and provider in ('IMA','GP')
    and telemetry_enabled=true;

  if v_link_count<>2 then
    raise exception 'Bezpecnostni kontrola: EV80 nema obe aktivni vazby IMA/GP pro TID 592150 (nalezeno %).',v_link_count;
  end if;

  select id into strict v_machine_stock_location_id
  from public.stock_locations
  where location_type='machine' and machine_id=v_machine_id and active=true;

  if exists (
    select 1 from public.machine_transfers
    where machine_id=v_machine_id
      and from_location_id=v_from_location_id
      and to_location_id is null
      and transfer_kind='storage'
      and note like '%EV80_VITAR_DILNA_20260904%'
  ) then
    raise exception 'Presun EV80 z Vitaru do dilny uz byl zapsan.';
  end if;

  update public.machine_external_links
  set telemetry_enabled=false,
      note='TID 592150 · vazba deaktivována 4. 9. 2026 při stažení LEI 600 Touch EV80 z Vitaru do dílny; historie ponechána, terminál rezervován pro další nově zakládaný automat.',
      updated_at=now()
  where machine_id=v_machine_id
    and external_machine_id='592150'
    and provider in ('IMA','GP');

  get diagnostics v_link_count=row_count;
  if v_link_count<>2 then
    raise exception 'Deaktivace TID 592150 selhala: ocekavany 2 vazby, upraveno %.',v_link_count;
  end if;

  insert into public.machine_transfers(
    machine_id,from_location_id,to_location_id,transfer_kind,
    from_status,to_status,from_active,to_active,transferred_at,transferred_by,
    note,from_stock_location_id,to_stock_location_id
  ) values (
    v_machine_id,v_from_location_id,null,'storage',
    'ok','removed',true,true,now(),'Codex / potvrzeno Michal Punčochář',
    'LEI 600 Touch EV80 přesunut z Vitaru do dílny/skladu Blučina dne 4. 9. 2026. TID 592150 deaktivován a rezervován pro další nový automat; evidovaný obsah zůstává u stroje. EV80_VITAR_DILNA_20260904',
    v_machine_stock_location_id,null
  );

  update public.machines
  set location_id=null,
      status='removed',
      active=true,
      sales_tracking_mode='none',
      note=concat_ws(' ',nullif(note,''),'· 4. 9. 2026: staženo z lokality Vitar do dílny/skladu Blučina; TID 592150 deaktivován a rezervován pro další nový automat, evidovaný obsah ponechán u stroje. · EV80_VITAR_DILNA_20260904'),
      updated_at=now()
  where id=v_machine_id;

  update public.machine_telemetry_state
  set connectivity_status='offline',updated_at=now()
  where machine_id=v_machine_id;

  if not exists (
    select 1 from public.machines
    where id=v_machine_id and location_id is null and status='removed'
      and active=true and sales_tracking_mode='none'
  ) then
    raise exception 'Zaverecna kontrola stavu EV80 selhala.';
  end if;

  if exists (
    select 1 from public.machine_external_links
    where machine_id=v_machine_id and telemetry_enabled=true
  ) then
    raise exception 'Zaverecna kontrola: EV80 ma stale aktivni telemetrickou vazbu.';
  end if;
end $$;

commit;

select m.evidence_number,m.name,m.location_id,m.status,m.active,m.sales_tracking_mode,
       count(l.id) filter(where l.telemetry_enabled) active_telemetry_links,
       array_agg(l.external_machine_id order by l.provider) filter(where l.external_machine_id is not null) retained_terminal_ids
from public.machines m
left join public.machine_external_links l on l.machine_id=m.id
where m.evidence_number=80
group by m.id,m.evidence_number,m.name,m.location_id,m.status,m.active,m.sales_tracking_mode;

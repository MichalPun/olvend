-- EV86 Luce X2 I8: fyzicky presun z lokality Vitar do dilny/skladu Blucina.
-- V OLVEND se dilna eviduje jako stroj bez zakaznicke lokality,
-- active=true (majetkova karta zustava aktivni) a status='removed'.

begin;

do $$
declare
  v_machine_id bigint;
  v_from_location_id bigint;
  v_machine_stock_location_id bigint;
begin
  select id,location_id
  into strict v_machine_id,v_from_location_id
  from public.machines
  where evidence_number=86
    and name='Luce X2 I8'
    and location_id=60
    and status='ok'
    and active=true;

  if not exists (select 1 from public.locations where id=60 and name='Vitar' and active=true) then
    raise exception 'Zdrojova lokalita Vitar ID60 nebyla nalezena.';
  end if;

  if exists (select 1 from public.machine_external_links where machine_id=v_machine_id and telemetry_enabled=true) then
    raise exception 'EV86 ma stale aktivni telemetrickou vazbu; presun byl zastaven.';
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
      and note like '%EV86_VITAR_DILNA_20260904%'
  ) then
    raise exception 'Presun EV86 z Vitaru do dilny uz byl zapsan.';
  end if;

  insert into public.machine_transfers (
    machine_id,from_location_id,to_location_id,transfer_kind,
    from_status,to_status,from_active,to_active,transferred_at,transferred_by,
    note,from_stock_location_id,to_stock_location_id
  ) values (
    v_machine_id,v_from_location_id,null,'storage',
    'ok','removed',true,true,now(),'Codex / potvrzeno Michal Punčochář',
    'EV86 Luce X2 I8 přesunuta z Vitaru do dílny/skladu Blučina dne 4. 9. 2026. EV86_VITAR_DILNA_20260904',
    v_machine_stock_location_id,null
  );

  update public.machines
  set location_id=null,
      status='removed',
      active=true,
      sales_tracking_mode='none',
      note=concat_ws(' ',nullif(note,''),'· 4. 9. 2026: přesunuto z lokality Vitar do dílny/skladu Blučina; platební terminál TID 602227 předán do Jetinno EV125. · EV86_VITAR_DILNA_20260904'),
      updated_at=now()
  where id=v_machine_id;

  if not exists (
    select 1 from public.machines
    where id=v_machine_id and location_id is null and status='removed' and active=true and sales_tracking_mode='none'
  ) then
    raise exception 'Zaverecna kontrola stavu EV86 selhala.';
  end if;
end $$;

commit;

select evidence_number,name,location_id,status,active,sales_tracking_mode,note
from public.machines
where evidence_number=86;

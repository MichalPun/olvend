-- Presun platebniho terminalu TID 602227 z Vitar Luce X2 I8 (EV86)
-- na Jetinno JL300 (EV125) a oprava maximalni kapacity kelimku na 450 ks.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_target_machine_id bigint;
  v_count integer;
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number = 86
    and name = 'Luce X2 I8';

  select id into strict v_target_machine_id
  from public.machines
  where evidence_number = 125
    and brand = 'Jetinno'
    and model = 'JL300';

  if v_source_machine_id = v_target_machine_id then
    raise exception 'Zdrojovy a cilovy stroj nesmi byt shodne.';
  end if;

  if (select count(*) from public.machine_external_links
      where machine_id = v_source_machine_id
        and external_machine_id = '602227'
        and provider in ('IMA','GP')
        and telemetry_enabled = true) <> 2 then
    raise exception 'Bezpecnostni kontrola: na EV86 nebyly nalezeny obe aktivni vazby IMA/GP pro TID 602227.';
  end if;

  if exists (select 1 from public.machine_external_links where machine_id = v_target_machine_id) then
    raise exception 'Bezpecnostni kontrola: EV125 uz ma jinou externi telemetrickou vazbu.';
  end if;

  if exists (select 1 from public.telemetry_planogram_counters where machine_id = v_target_machine_id)
     or exists (select 1 from public.telemetry_sales_events where machine_id = v_target_machine_id)
     or exists (select 1 from public.machine_telemetry_state where machine_id = v_target_machine_id) then
    raise exception 'Bezpecnostni kontrola: EV125 uz obsahuje telemetrickou historii nebo vychozi citace.';
  end if;

  update public.machine_coffee_containers
  set capacity_quantity = 450,
      note = 'Jetinno JL300 ES7C · zasobnik automaticky vydavanych kelimku 250 ml · maximalni napln 450 ks · vychozi stav 0 ks.'
  where machine_id = v_target_machine_id
    and container_code = 'Z8'
    and product_sku = '255'
    and active = true;

  get diagnostics v_count = row_count;
  if v_count <> 1 then
    raise exception 'Oprava kapacity kelimku selhala: ocekavan 1 zasobnik, upraveno %.', v_count;
  end if;

  update public.machine_external_links
  set machine_id = v_target_machine_id,
      telemetry_enabled = true,
      note = 'TID 602227 · platebni terminal presunut z Vitar Luce X2 I8 EV86 na Jetinno JL300 EV125 dne 2026-09-04. Historie do okamziku presunu zustava na EV86; nove prenosy patri EV125.',
      updated_at = now()
  where machine_id = v_source_machine_id
    and external_machine_id = '602227'
    and provider in ('IMA','GP');

  get diagnostics v_count = row_count;
  if v_count <> 2 then
    raise exception 'Presun telemetrickych vazeb selhal: ocekavany 2 radky, upraveno %.', v_count;
  end if;

  update public.machines
  set sales_tracking_mode = 'telemetry'
  where id = v_target_machine_id;

  if (select count(*) from public.machine_external_links
      where machine_id = v_target_machine_id
        and external_machine_id = '602227'
        and provider in ('IMA','GP')
        and telemetry_enabled = true) <> 2 then
    raise exception 'Zaverecna kontrola: EV125 nema obe aktivni vazby IMA/GP.';
  end if;

  if exists (select 1 from public.machine_external_links
             where machine_id = v_source_machine_id
               and external_machine_id = '602227'
               and provider in ('IMA','GP')) then
    raise exception 'Zaverecna kontrola: na EV86 zustala vazba terminalu 602227.';
  end if;

  if not exists (select 1 from public.machine_coffee_containers
                 where machine_id = v_target_machine_id
                   and container_code = 'Z8'
                   and product_sku = '255'
                   and capacity_quantity = 450
                   and active = true) then
    raise exception 'Zaverecna kontrola: kapacita zasobniku kelimku EV125 neni 450 ks.';
  end if;
end $$;

commit;

select
  m.evidence_number,
  m.name,
  c.capacity_quantity as cup_capacity,
  c.current_quantity as cup_current_quantity,
  array_agg(l.provider order by l.provider) as telemetry_providers,
  min(l.external_machine_id) as terminal_id
from public.machines m
join public.machine_coffee_containers c
  on c.machine_id = m.id and c.container_code = 'Z8' and c.product_sku = '255' and c.active
join public.machine_external_links l
  on l.machine_id = m.id and l.external_machine_id = '602227' and l.telemetry_enabled
where m.evidence_number = 125
group by m.evidence_number,m.name,c.capacity_quantity,c.current_quantity;

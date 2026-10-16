-- Aktivní telemetrické napojení a režim evidence stroje musí být vždy konzistentní.
-- Trigger chrání uložení, přesun i odebrání TID bez závislosti na konkrétním UI.

create or replace function public.sync_machine_tracking_mode_from_telemetry_link()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_old_machine_id bigint;
  v_new_machine_id bigint;
begin
  v_old_machine_id := case when tg_op in ('UPDATE', 'DELETE') then old.machine_id else null end;
  v_new_machine_id := case when tg_op in ('INSERT', 'UPDATE') then new.machine_id else null end;

  if tg_op in ('INSERT', 'UPDATE') and new.telemetry_enabled then
    update public.machines
    set sales_tracking_mode = 'telemetry',
        updated_at = now()
    where id = v_new_machine_id
      and sales_tracking_mode <> 'telemetry';
  end if;

  if v_old_machine_id is not null
     and (tg_op = 'DELETE' or v_old_machine_id is distinct from v_new_machine_id or not new.telemetry_enabled)
     and not exists (
       select 1
       from public.machine_external_links link
       where link.machine_id = v_old_machine_id
         and link.telemetry_enabled = true
     ) then
    update public.machines
    set sales_tracking_mode = 'none',
        updated_at = now()
    where id = v_old_machine_id
      and sales_tracking_mode = 'telemetry';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_sync_machine_tracking_mode_from_telemetry_link
  on public.machine_external_links;

create trigger trg_sync_machine_tracking_mode_from_telemetry_link
after insert or update or delete on public.machine_external_links
for each row
execute function public.sync_machine_tracking_mode_from_telemetry_link();

do $$
declare
  v_machine record;
begin
  for v_machine in
    select expected.id, expected.evidence_number, expected.provider, expected.external_machine_id
    from (values
      (58::bigint, 78::bigint, 'IMA'::text, '635461'::text),
      (66::bigint, 86::bigint, 'IMA'::text, '602224'::text)
    ) as expected(id, evidence_number, provider, external_machine_id)
  loop
    if not exists (
      select 1
      from public.machines machine
      join public.machine_external_links link on link.machine_id = machine.id
      join public.machine_telemetry_state telemetry
        on telemetry.machine_id = machine.id
       and telemetry.provider = link.provider
      where machine.id = v_machine.id
        and machine.evidence_number = v_machine.evidence_number
        and machine.active = true
        and machine.status <> 'removed'
        and machine.location_id is not null
        and link.provider = v_machine.provider
        and link.external_machine_id = v_machine.external_machine_id
        and link.telemetry_enabled = true
        and telemetry.connectivity_status = 'online'
        and telemetry.last_seen_at >= now() - interval '24 hours'
    ) then
      raise exception 'EV % nema overene aktivni online napojeni % %.',
        v_machine.evidence_number, v_machine.provider, v_machine.external_machine_id;
    end if;

    update public.machines
    set sales_tracking_mode = 'telemetry',
        updated_at = now()
    where id = v_machine.id;
  end loop;

  update public.machine_planogram_slots slot
  set desired_units = greatest(
        0,
        least(coalesce(slot.target_units, slot.capacity_units, 0), coalesce(slot.capacity_units, 0))
          - least(coalesce(slot.current_units, 0), least(coalesce(slot.target_units, slot.capacity_units, 0), coalesce(slot.capacity_units, 0)))
      ),
      fill_percent = case
        when coalesce(slot.capacity_units, 0) > 0
          then round(least(100, greatest(0, coalesce(slot.current_units, 0) * 100.0 / slot.capacity_units)), 2)
        else 0
      end,
      updated_at = now()
  where slot.machine_id in (58, 66)
    and slot.active = true;

  if exists (
    select 1
    from public.machines machine
    where machine.id in (58, 66)
      and machine.sales_tracking_mode <> 'telemetry'
  ) then
    raise exception 'EV 78 nebo EV 86 zustal mimo telemetricky rezim.';
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots slot
    where slot.machine_id in (58, 66)
      and slot.active = true
      and coalesce(slot.current_units, 0) >= least(coalesce(slot.target_units, slot.capacity_units, 0), coalesce(slot.capacity_units, 0))
      and coalesce(slot.desired_units, 0) > 0
  ) then
    raise exception 'Plna pozice EV 78 nebo EV 86 ma po oprave stale pozadavek na doplneni.';
  end if;
end;
$$;

comment on function public.sync_machine_tracking_mode_from_telemetry_link() is
  'Udrzuje machines.sales_tracking_mode konzistentni s aktivnim telemetrickym napojenim.';

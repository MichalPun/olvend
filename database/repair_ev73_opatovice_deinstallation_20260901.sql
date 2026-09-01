begin;

do $$
declare
  v_machine public.machines%rowtype;
  v_job public.technical_jobs%rowtype;
  v_transfer_id bigint;
  v_now timestamptz := now();
begin
  select * into strict v_machine
  from public.machines
  where evidence_number = 73
  for update;

  if v_machine.id <> 53 then
    raise exception 'EV 73 neodpovídá očekávanému stroji ID 53.';
  end if;

  select * into strict v_job
  from public.technical_jobs
  where id = 9
    and job_type = 'deinstallation'
    and machine_id = v_machine.id
  for update;

  if v_machine.location_id is distinct from 47
     and not (v_machine.location_id is null and v_machine.status = 'removed') then
    raise exception 'EV 73 už není na očekávané výchozí lokalitě Opatovice (47).';
  end if;

  select mt.id into v_transfer_id
  from public.machine_transfers mt
  where mt.technical_job_id = v_job.id
  limit 1;

  if v_transfer_id is null then
    insert into public.machine_transfers (
      machine_id,
      technical_job_id,
      from_location_id,
      to_location_id,
      from_stock_location_id,
      to_stock_location_id,
      transfer_kind,
      from_status,
      to_status,
      from_active,
      to_active,
      transferred_at,
      transferred_by,
      note
    ) values (
      v_machine.id,
      v_job.id,
      47,
      null,
      null,
      coalesce(v_job.target_stock_location_id, 1),
      'storage',
      v_machine.status,
      'removed',
      v_machine.active,
      true,
      v_now,
      'Administrativní potvrzení OLVEND',
      'TZ-0009 · EV 73 je fyzicky ve skladu; potvrzeno Michalem Punčochářem 1. 9. 2026.'
    )
    returning id into v_transfer_id;
  end if;

  update public.machines
  set location_id = null,
      status = 'removed',
      active = true,
      note = concat_ws(
        ' · ',
        nullif(note, ''),
        'Staženo z TEXTILOMÁNIE Opatovice do skladu; fyzický stav potvrzen 1. 9. 2026.'
      ),
      updated_at = v_now
  where id = v_machine.id;

  update public.technical_jobs
  set status = 'closed',
      picked_up_at = coalesce(picked_up_at, v_now),
      delivered_at = coalesce(delivered_at, v_now),
      finished_at = coalesce(finished_at, v_now),
      submitted_at = coalesce(submitted_at, v_now),
      result = 'EV 73 přijat na sklad; fyzický stav potvrzen 1. 9. 2026.',
      machine_transfer_id = v_transfer_id,
      updated_at = v_now
  where id = v_job.id;
end;
$$;

commit;

select
  m.id,
  m.evidence_number,
  m.location_id,
  m.status,
  m.active,
  tj.id as technical_job_id,
  tj.status as technical_job_status,
  tj.machine_transfer_id,
  mt.to_stock_location_id,
  mt.transferred_at
from public.machines m
join public.technical_jobs tj on tj.id = 9 and tj.machine_id = m.id
left join public.machine_transfers mt on mt.id = tj.machine_transfer_id
where m.evidence_number = 73;

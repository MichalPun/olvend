begin;

-- Technicky prevoz musi mit jednu auditovatelou stopu. Vazba na kartu zaroven
-- zajistuje idempotenci: opakovane klepnuti v mobilu uz stroj nepresune podruhe.
alter table public.machine_transfers
  add column if not exists technical_job_id bigint references public.technical_jobs(id) on delete set null,
  add column if not exists from_stock_location_id bigint references public.stock_locations(id) on delete set null,
  add column if not exists to_stock_location_id bigint references public.stock_locations(id) on delete set null;

create unique index if not exists machine_transfers_technical_job_unique_idx
  on public.machine_transfers(technical_job_id)
  where technical_job_id is not null;

alter table public.technical_jobs
  add column if not exists machine_transfer_id bigint references public.machine_transfers(id) on delete set null;

create index if not exists technical_jobs_machine_transfer_idx
  on public.technical_jobs(machine_transfer_id);

create or replace function public.complete_technician_transport_v46(
  p_job_id bigint,
  p_employee_id uuid,
  p_receiver text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_employee_id uuid;
  v_role text;
  v_employee_label text;
  v_job public.technical_jobs%rowtype;
  v_machine public.machines%rowtype;
  v_transfer_id bigint;
  v_from_location_id bigint;
  v_to_location_id bigint;
  v_from_stock_location_id bigint;
  v_to_stock_location_id bigint;
  v_transfer_kind text;
  v_to_status text;
  v_to_active boolean;
  v_now timestamptz := now();
begin
  select e.id, lower(coalesce(e.role, '')), trim(concat_ws(' ', e.name, e.surname))
    into v_auth_employee_id, v_role, v_employee_label
  from public.employees e
  where e.auth_user_id = auth.uid() and coalesce(e.active, true)
  limit 1;

  if v_auth_employee_id is null then
    raise exception 'Přihlášený uživatel nemá aktivní profil zaměstnance.';
  end if;
  if v_auth_employee_id <> p_employee_id
     and v_role not in ('admin', 'manager', 'vedoucí', 'vedouci') then
    raise exception 'Převoz může potvrdit jen přiřazený technik nebo vedoucí.';
  end if;

  select * into v_job
  from public.technical_jobs
  where id = p_job_id
  for update;

  if not found then raise exception 'Technická karta neexistuje.'; end if;
  if v_job.assigned_employee_id is distinct from p_employee_id
     and v_role not in ('admin', 'manager', 'vedoucí', 'vedouci') then
    raise exception 'Technická karta není přiřazená tomuto technikovi.';
  end if;
  if v_job.job_type not in ('transfer', 'deinstallation', 'installation', 'delivery') then
    raise exception 'Tato technická karta není převoz.';
  end if;

  select mt.id into v_transfer_id
  from public.machine_transfers mt
  where mt.technical_job_id = v_job.id;

  if v_job.machine_transfer_id is not null or v_transfer_id is not null then
    v_transfer_id := coalesce(v_job.machine_transfer_id, v_transfer_id);
    update public.technical_jobs
    set machine_transfer_id = v_transfer_id,
        status = case when status = 'closed' then status else 'pending_confirmation' end,
        delivered_at = coalesce(delivered_at, v_now),
        finished_at = coalesce(finished_at, v_now),
        submitted_at = coalesce(submitted_at, v_now),
        transport_receiver_name = coalesce(nullif(trim(coalesce(p_receiver, '')), ''), transport_receiver_name),
        transport_completion_note = coalesce(nullif(trim(coalesce(p_note, '')), ''), transport_completion_note)
    where id = v_job.id;
    return jsonb_build_object('already_applied', true, 'machine_transfer_id', v_transfer_id);
  end if;

  -- Zavoz materialu muze byt bez stroje; karta se presto dokonci jednim RPC.
  if v_job.machine_id is not null then
    select * into v_machine from public.machines where id = v_job.machine_id for update;
    if not found then raise exception 'Automat z technické karty neexistuje.'; end if;

    v_from_location_id := v_machine.location_id;
    v_from_stock_location_id := v_job.source_stock_location_id;
    v_to_stock_location_id := v_job.target_stock_location_id;

    if v_job.job_type in ('transfer', 'deinstallation')
       and coalesce(v_job.source_location_id, v_job.location_id) is not null
       and v_machine.location_id is distinct from coalesce(v_job.source_location_id, v_job.location_id) then
      raise exception 'Automat už není na výchozí lokalitě uvedené na kartě. Obnovte kartu a zkontrolujte jeho skutečné umístění.';
    end if;

    if v_job.job_type = 'deinstallation' then
      if v_job.target_stock_location_id is null then
        raise exception 'Na kartě chybí cílová dílna nebo sklad.';
      end if;
      v_transfer_kind := 'storage';
      v_to_location_id := null;
      v_to_status := 'removed';
      v_to_active := true;
    else
      v_to_location_id := coalesce(v_job.target_location_id, v_job.location_id);
      if v_to_location_id is null then
        raise exception 'Na kartě chybí cílová lokalita.';
      end if;
      v_transfer_kind := 'relocation';
      v_to_status := 'ok';
      v_to_active := true;
    end if;

    update public.machines
    set location_id = v_to_location_id,
        status = v_to_status,
        active = v_to_active
    where id = v_machine.id;

    insert into public.machine_transfers(
      machine_id, technical_job_id,
      from_location_id, to_location_id,
      from_stock_location_id, to_stock_location_id,
      transfer_kind, from_status, to_status, from_active, to_active,
      transferred_at, transferred_by, note
    ) values (
      v_machine.id, v_job.id,
      v_from_location_id, v_to_location_id,
      v_from_stock_location_id, v_to_stock_location_id,
      v_transfer_kind, v_machine.status, v_to_status, v_machine.active, v_to_active,
      v_now, nullif(v_employee_label, ''),
      concat_ws(' · ', 'TZ-' || lpad(v_job.id::text, 4, '0'), nullif(trim(coalesce(p_note, '')), ''))
    ) returning id into v_transfer_id;
  end if;

  update public.technical_jobs
  set status = 'pending_confirmation',
      picked_up_at = coalesce(picked_up_at, v_now),
      delivered_at = v_now,
      finished_at = v_now,
      submitted_at = v_now,
      transport_receiver_name = nullif(trim(coalesce(p_receiver, '')), ''),
      transport_completion_note = nullif(trim(coalesce(p_note, '')), ''),
      result = concat_ws(' · ',
        case when v_job.job_type = 'deinstallation' then 'Přijato na sklad / dílnu' else 'Předáno v cíli' end,
        nullif(trim(coalesce(p_receiver, '')), ''),
        nullif(trim(coalesce(p_note, '')), '')
      ),
      machine_transfer_id = v_transfer_id
  where id = v_job.id;

  return jsonb_build_object(
    'already_applied', false,
    'machine_transfer_id', v_transfer_id,
    'machine_id', v_job.machine_id,
    'location_id', v_to_location_id,
    'stock_location_id', v_to_stock_location_id,
    'machine_status', v_to_status
  );
end;
$$;

revoke all on function public.complete_technician_transport_v46(bigint, uuid, text, text) from public, anon;
grant execute on function public.complete_technician_transport_v46(bigint, uuid, text, text) to authenticated;

commit;

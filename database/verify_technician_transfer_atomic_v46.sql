begin;

do $$
declare
  v_employee_id uuid;
  v_auth_user_id uuid;
  v_machine_id bigint;
  v_source_location_id bigint;
  v_target_location_id bigint;
  v_job_id bigint;
  v_first_transfer_id bigint;
  v_second_transfer_id bigint;
  v_result jsonb;
  v_transfer_count integer;
begin
  select e.id, e.auth_user_id
    into v_employee_id, v_auth_user_id
  from public.employees e
  where e.auth_user_id is not null
    and coalesce(e.active, true)
    and lower(coalesce(e.role, '')) ~ '(technik|technician|admin|manager)'
  order by case when lower(coalesce(e.role, '')) ~ '(technik|technician)' then 0 else 1 end, e.created_at
  limit 1;

  select m.id, m.location_id
    into v_machine_id, v_source_location_id
  from public.machines m
  where m.location_id is not null and coalesce(m.active, true)
  order by m.id
  limit 1;

  select l.id into v_target_location_id
  from public.locations l
  where l.id <> v_source_location_id and coalesce(l.active, true)
  order by l.id
  limit 1;

  if v_employee_id is null or v_machine_id is null or v_target_location_id is null then
    raise exception 'Chybí bezpečná data pro transakční ověření.';
  end if;

  perform set_config('request.jwt.claim.sub', v_auth_user_id::text, true);

  insert into public.technical_jobs(
    job_type, status, priority, title, description,
    location_id, source_location_id, target_location_id, machine_id,
    assigned_employee_id, qr_token, active
  ) values (
    'transfer', 'assigned', 'normal', 'TEST v46 – transakce bude vrácena',
    'Automatický test atomického přesunu',
    v_source_location_id, v_source_location_id, v_target_location_id, v_machine_id,
    v_employee_id, 'test-v46-' || gen_random_uuid()::text, true
  ) returning id into v_job_id;

  select public.complete_technician_transport_v46(v_job_id, v_employee_id, 'Test', 'ROLLBACK test') into v_result;
  v_first_transfer_id := (v_result ->> 'machine_transfer_id')::bigint;

  if (select location_id from public.machines where id = v_machine_id) is distinct from v_target_location_id then
    raise exception 'Automat po potvrzení nemá cílovou lokalitu.';
  end if;
  if (select machine_transfer_id from public.technical_jobs where id = v_job_id) is distinct from v_first_transfer_id then
    raise exception 'Technická karta nemá vazbu na historii přesunu.';
  end if;

  select public.complete_technician_transport_v46(v_job_id, v_employee_id, 'Test', 'Opakované potvrzení') into v_result;
  v_second_transfer_id := (v_result ->> 'machine_transfer_id')::bigint;
  select count(*) into v_transfer_count from public.machine_transfers where technical_job_id = v_job_id;

  if v_second_transfer_id is distinct from v_first_transfer_id or v_transfer_count <> 1 then
    raise exception 'Opakované potvrzení vytvořilo duplicitní přesun.';
  end if;

  raise notice 'OK: karta %, stroj %, přesun %; lokalita, historie a idempotence ověřeny.', v_job_id, v_machine_id, v_first_transfer_id;
end;
$$;

rollback;

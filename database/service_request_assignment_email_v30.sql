begin;

create unique index if not exists email_notification_queue_service_request_dedupe_unique
  on public.email_notification_queue ((metadata ->> 'dedupe_key'))
  where kind in ('service_request_assignment', 'service_request_update');

create or replace function public.queue_service_request_assignment_notification(
  p_service_request_id bigint,
  p_force_update boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.service_requests%rowtype;
  v_employee record;
  v_location record;
  v_machine record;
  v_payload jsonb;
  v_fingerprint text;
  v_dedupe_key text;
  v_kind text;
  v_queue_id bigint;
begin
  select * into v_request
  from public.service_requests
  where id = p_service_request_id;

  if v_request.id is null then
    raise exception 'Service request % was not found', p_service_request_id;
  end if;
  if v_request.assigned_employee_id is null then
    return jsonb_build_object('queued', false, 'reason', 'unassigned');
  end if;

  select id, name, surname, email, active into v_employee
  from public.employees
  where id = v_request.assigned_employee_id;
  if not coalesce(v_employee.active, false) or nullif(trim(v_employee.email), '') is null then
    return jsonb_build_object('queued', false, 'reason', 'employee_email_missing');
  end if;

  select id, name, city, address, contact_person, contact_phone, contact_email into v_location
  from public.locations
  where id = v_request.location_id;
  select id, name, machine_type, brand, model, serial_number, evidence_number into v_machine
  from public.machines
  where id = v_request.machine_id;

  v_payload := jsonb_build_object(
    'service_request_id', v_request.id,
    'title', v_request.title,
    'description', v_request.description,
    'priority', v_request.priority,
    'status', v_request.status,
    'due_date', v_request.due_date,
    'employee', to_jsonb(v_employee),
    'location', to_jsonb(v_location),
    'machine', to_jsonb(v_machine)
  );
  v_fingerprint := md5(v_payload::text);
  v_dedupe_key := format(
    'service-request:%s:%s:%s%s',
    v_request.id,
    v_request.assigned_employee_id,
    v_fingerprint,
    case when p_force_update then ':' || floor(extract(epoch from clock_timestamp()) * 1000)::bigint::text else '' end
  );
  v_kind := case when p_force_update then 'service_request_update' else 'service_request_assignment' end;

  insert into public.email_notification_queue (
    employee_id, kind, subject, body, action_url, metadata
  ) values (
    v_request.assigned_employee_id,
    v_kind,
    format('OLVEND: servis SR-%s · %s', lpad(v_request.id::text, 4, '0'), v_request.title),
    concat_ws(E'\n',
      v_request.title,
      'Lokalita: ' || coalesce(v_location.name, 'neuvedena'),
      'Automat: ' || coalesce(v_machine.name, 'obecně na lokalitu'),
      'Termín: ' || coalesce(to_char(v_request.due_date, 'DD.MM.YYYY'), 'bez termínu'),
      'Priorita: ' || v_request.priority,
      '',
      nullif(v_request.description, '')
    ),
    'service-requests.html?request=' || v_request.id,
    v_payload || jsonb_build_object('dedupe_key', v_dedupe_key)
  )
  on conflict do nothing
  returning id into v_queue_id;

  return jsonb_build_object(
    'queued', v_queue_id is not null,
    'queue_id', v_queue_id,
    'kind', v_kind,
    'dedupe_key', v_dedupe_key
  );
end;
$$;

grant execute on function public.queue_service_request_assignment_notification(bigint, boolean) to authenticated;

commit;

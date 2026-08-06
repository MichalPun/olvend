create table if not exists public.service_request_notification_recipients (
  employee_id uuid primary key references public.employees (id) on delete cascade,
  active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

alter table public.service_request_notification_recipients enable row level security;

drop policy if exists "Allow authenticated read service notification recipients" on public.service_request_notification_recipients;
create policy "Allow authenticated read service notification recipients"
on public.service_request_notification_recipients for select to authenticated using (true);

drop policy if exists "Allow authenticated insert service notification recipients" on public.service_request_notification_recipients;
create policy "Allow authenticated insert service notification recipients"
on public.service_request_notification_recipients for insert to authenticated with check (true);

drop policy if exists "Allow authenticated update service notification recipients" on public.service_request_notification_recipients;
create policy "Allow authenticated update service notification recipients"
on public.service_request_notification_recipients for update to authenticated using (true) with check (true);

drop policy if exists "Allow authenticated delete service notification recipients" on public.service_request_notification_recipients;
create policy "Allow authenticated delete service notification recipients"
on public.service_request_notification_recipients for delete to authenticated using (true);

alter table public.email_notification_queue
  drop constraint if exists email_notification_queue_status_check;

alter table public.email_notification_queue
  add constraint email_notification_queue_status_check
  check (status in ('queued', 'processing', 'sent', 'failed'));

create unique index if not exists email_notification_queue_qr_service_recipient_unique
  on public.email_notification_queue (employee_id, ((metadata ->> 'service_request_id')::bigint))
  where kind = 'qr_service_request';

create or replace function public.queue_qr_service_request_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  machine_name text;
  location_name text;
begin
  if new.machine_id is null then
    return new;
  end if;

  select m.name into machine_name from public.machines m where m.id = new.machine_id;
  select l.name into location_name from public.locations l where l.id = new.location_id;

  insert into public.email_notification_queue (
    employee_id, kind, subject, body, action_url, metadata
  )
  select
    recipient.employee_id,
    'qr_service_request',
    case new.priority
      when 'critical' then 'OLVEND: KRITICKÉ hlášení poruchy'
      when 'high' then 'OLVEND: urgentní hlášení poruchy'
      else 'OLVEND: nové hlášení poruchy'
    end || coalesce(' – ' || machine_name, ''),
    concat_ws(E'\n',
      coalesce(new.title, 'Nové servisní hlášení'),
      'Automat: ' || coalesce(machine_name, 'neuvedeno'),
      'Lokalita: ' || coalesce(location_name, 'neuvedena'),
      'Priorita: ' || case new.priority when 'critical' then 'kritická' when 'high' then 'urgentní' else 'běžná' end,
      '',
      nullif(new.description, '')
    ),
    'service-requests.html?request=' || new.id,
    jsonb_build_object(
      'service_request_id', new.id,
      'machine_id', new.machine_id,
      'location_id', new.location_id,
      'priority', new.priority,
      'source', 'machine_qr'
    )
  from public.service_request_notification_recipients recipient
  join public.employees employee on employee.id = recipient.employee_id
  left join public.notification_preferences preference on preference.employee_id = recipient.employee_id
  where recipient.active = true
    and employee.active = true
    and employee.email is not null
    and btrim(employee.email) <> ''
    and coalesce(preference.email_enabled, true) = true
    and coalesce(preference.notify_service, true) = true
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists trg_queue_qr_service_request_notifications on public.service_requests;
create trigger trg_queue_qr_service_request_notifications
after insert on public.service_requests
for each row
execute function public.queue_qr_service_request_notifications();

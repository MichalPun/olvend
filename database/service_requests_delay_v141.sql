alter table public.service_requests
  add column if not exists delay_reason text,
  add column if not exists delay_note text;

alter table public.service_requests
  drop constraint if exists service_requests_status_check;

alter table public.service_requests
  add constraint service_requests_status_check
  check (status in ('new', 'assigned', 'on_site', 'in_progress', 'blocked', 'done', 'return_with_part', 'cancelled'));

alter table public.service_requests
  drop constraint if exists service_requests_delay_reason_check;

alter table public.service_requests
  add constraint service_requests_delay_reason_check
  check (
    delay_reason is null
    or delay_reason in ('waiting_part', 'waiting_customer', 'missed', 'need_help', 'other')
  );

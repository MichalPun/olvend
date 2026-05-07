alter table public.service_requests
  add column if not exists service_result text,
  add column if not exists work_performed text,
  add column if not exists used_parts text,
  add column if not exists next_recommendation text,
  add column if not exists internal_service_note text;

alter table public.service_requests
  drop constraint if exists service_requests_service_result_check;

alter table public.service_requests
  add constraint service_requests_service_result_check
  check (
    service_result in (
      'fixed',
      'temporary_fixed',
      'need_spare_part',
      'need_machine_replacement',
      'not_found',
      'return_later'
    )
    or service_result is null
  );

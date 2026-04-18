alter table public.service_requests
  add column if not exists estimated_duration_minutes integer,
  add column if not exists actual_duration_minutes integer,
  add column if not exists service_started_at timestamp with time zone,
  add column if not exists service_finished_at timestamp with time zone,
  add column if not exists last_service_result text;

alter table public.service_requests
  drop constraint if exists service_requests_last_service_result_check;

alter table public.service_requests
  add constraint service_requests_last_service_result_check
  check (last_service_result in ('fixed', 'return_with_part'));

create or replace function public.set_service_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  if new.service_started_at is not null and new.service_finished_at is not null then
    new.actual_duration_minutes = greatest(0, floor(extract(epoch from (new.service_finished_at - new.service_started_at)) / 60));
  end if;
  if new.status = 'done' and new.resolved_at is null then
    new.resolved_at = now();
  end if;
  if new.status <> 'done' then
    new.resolved_at = null;
  end if;
  return new;
end;
$$;

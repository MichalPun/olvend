alter table public.service_requests
  add column if not exists machine_id bigint references public.machines (id) on delete set null,
  add column if not exists service_arrived_at timestamp with time zone,
  add column if not exists service_departed_at timestamp with time zone;

create index if not exists service_requests_machine_idx
  on public.service_requests (machine_id);

alter table public.service_requests
  drop constraint if exists service_requests_status_check;

alter table public.service_requests
  add constraint service_requests_status_check
  check (status in ('new', 'assigned', 'on_site', 'in_progress', 'done', 'return_with_part', 'cancelled'));

create or replace function public.set_service_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();

  if new.service_arrived_at is not null and new.service_started_at is null then
    new.service_started_at = new.service_arrived_at;
  end if;

  if new.service_departed_at is not null and new.service_finished_at is null then
    new.service_finished_at = new.service_departed_at;
  end if;

  if new.service_started_at is not null and new.service_finished_at is not null then
    new.actual_duration_minutes = greatest(0, floor(extract(epoch from (new.service_finished_at - new.service_started_at)) / 60));
  end if;

  if new.status = 'done' and new.resolved_at is null then
    new.resolved_at = now();
  end if;

  if new.status not in ('done') then
    new.resolved_at = null;
  end if;

  if new.status = 'return_with_part' and new.last_service_result is null then
    new.last_service_result = 'return_with_part';
  end if;

  return new;
end;
$$;

create extension if not exists pg_cron with schema pg_catalog;

create index if not exists telemetry_dex_ingests_created_at_idx
  on public.telemetry_dex_ingests (created_at);

create or replace function public.cleanup_telemetry_dex_history(retention_days integer default 7)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_rows bigint;
begin
  delete from public.telemetry_dex_ingests
  where created_at < now() - make_interval(days => greatest(retention_days, 1));

  get diagnostics deleted_rows = row_count;
  return deleted_rows;
end;
$$;

revoke all on function public.cleanup_telemetry_dex_history(integer) from public;
grant execute on function public.cleanup_telemetry_dex_history(integer) to service_role;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
    into existing_job_id
  from cron.job
  where jobname = 'cleanup-telemetry-dex-history'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'cleanup-telemetry-dex-history',
    '17 3 * * *',
    $cron$select public.cleanup_telemetry_dex_history(7);$cron$
  );
end;
$$;

comment on function public.cleanup_telemetry_dex_history(integer) is
  'Deletes only expired raw DEX ingest envelopes. Derived sales, counters and machine telemetry state remain intact.';

begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
    into existing_job_id
  from cron.job
  where jobname = 'keepalive-ima-a5-render'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'keepalive-ima-a5-render',
    '*/5 * * * *',
    $cron$
      select net.http_get(
        url := 'https://olvend-telemetry-proxy.onrender.com/',
        timeout_milliseconds := 70000
      );
    $cron$
  );
end;
$$;

comment on extension pg_cron is
  'Keeps the temporary IMA A5 Render bridge awake and synchronizing every five minutes.';

commit;

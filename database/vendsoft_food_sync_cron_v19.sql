create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
    into existing_job_id
  from cron.job
  where jobname = 'sync-vendsoft-food-sales'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'sync-vendsoft-food-sales',
    '* * * * *',
    $cron$
      select net.http_post(
        url := 'https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/vendsoft-food-sync',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-olvend-cron-token', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'vendsoft_food_cron_token'
            limit 1
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000
      );
    $cron$
  );
end;
$$;

comment on extension pg_cron is
  'Runs the temporary VendSoft food transaction sync independently of the sleeping Render web service.';

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job where jobname = 'sync-vendsoft-food-sales'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

comment on function public.apply_vendsoft_food_sale(
  text, text, text, text, text, text, numeric, numeric, numeric, numeric, timestamp with time zone
) is 'Historický/záložní VendSoft import. Pravidelná synchronizace vypnuta 2026-07-31 po přechodu všech aktivních potravinových automatů na přímou IMA telemetrii.';

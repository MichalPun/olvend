begin;

drop index if exists public.telemetry_sales_events_ingest_slot_part_uidx;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.telemetry_sales_events'::regclass
      and conname = 'telemetry_sales_events_ingest_slot_part_key'
  ) then
    alter table public.telemetry_sales_events
      add constraint telemetry_sales_events_ingest_slot_part_key
      unique (provider, ingest_id, machine_id, planogram_slot_id, selection_code, event_part);
  end if;
end;
$$;

commit;
notify pgrst, 'reload schema';

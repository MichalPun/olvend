alter table public.telemetry_sales_events
  add column if not exists source_event_key text,
  add column if not exists source_location_name text,
  add column if not exists source_machine_name text;

drop index if exists public.telemetry_sales_events_provider_source_key_uidx;

create unique index telemetry_sales_events_provider_source_key_uidx
  on public.telemetry_sales_events (provider, source_event_key);

create index if not exists telemetry_sales_events_source_location_idx
  on public.telemetry_sales_events (source_location_name, source_event_at desc)
  where source_location_name is not null;

comment on column public.telemetry_sales_events.source_location_name is
  'Historická lokalita dodaná zdrojovým systémem v okamžiku prodeje; má přednost před dnešní lokalitou automatu.';

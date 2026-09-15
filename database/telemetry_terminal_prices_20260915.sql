begin;
alter table public.telemetry_sales_events
  add column if not exists price_source text,
  add column if not exists terminal_unit_price_czk numeric,
  add column if not exists planogram_unit_price_czk numeric;
comment on column public.telemetry_sales_events.price_source is 'dex_counter_delta: adjacent same-device PA2 money/quantity delta; planogram_estimate: no verified monetary amount, excluded from confirmed revenue. NULL: legacy/unverified source.';
commit;

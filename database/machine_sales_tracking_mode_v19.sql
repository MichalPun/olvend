alter table public.machines
  add column if not exists sales_tracking_mode text not null default 'telemetry'
  check (sales_tracking_mode in ('telemetry', 'manual_counters', 'none'));

update public.machines
set sales_tracking_mode = 'manual_counters',
    updated_at = now()
where evidence_number in (41, 44);

comment on column public.machines.sales_tracking_mode is
  'Zpusob evidence prodeju: telemetry, manual_counters (nemazaci trzba a porce), nebo none.';

begin;

alter table public.telemetry_sales_events
  add column if not exists unpaid_dispense_quantity numeric(12,3) not null default 0;

comment on column public.telemetry_sales_events.unpaid_dispense_quantity is
  'DEX product-counter increments without a matching payment-counter increment. These units reduce machine stock but do not create revenue unless a delayed payment is matched later.';

commit;

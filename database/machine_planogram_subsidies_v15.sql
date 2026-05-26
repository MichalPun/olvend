alter table public.machine_planogram_slots
  add column if not exists customer_price_czk numeric(10,2),
  add column if not exists subsidy_amount_czk numeric(10,2) not null default 0,
  add column if not exists subsidy_payer text,
  add column if not exists subsidy_billing_enabled boolean not null default false,
  add column if not exists subsidy_note text;

create index if not exists machine_planogram_slots_subsidy_idx
  on public.machine_planogram_slots (machine_id, subsidy_billing_enabled)
  where subsidy_billing_enabled = true;

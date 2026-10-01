begin;

alter table public.machine_planogram_slots
  add column if not exists customer_selection_code text;

comment on column public.machine_planogram_slots.customer_selection_code is
  'Volba viditelná zákazníkovi a tištěná na cenovce. slot_code a telemetry_key zůstávají interní/prodejní kódy automatu.';

update public.machine_planogram_slots
set customer_selection_code = null,
    updated_at = now()
where customer_selection_code is not null
  and btrim(customer_selection_code) = '';

alter table public.machine_planogram_slots
  drop constraint if exists machine_planogram_slots_customer_selection_code_check;

alter table public.machine_planogram_slots
  add constraint machine_planogram_slots_customer_selection_code_check
  check (customer_selection_code is null or btrim(customer_selection_code) <> '');

create unique index if not exists machine_planogram_slots_customer_selection_active_uidx
  on public.machine_planogram_slots (machine_id, customer_selection_code)
  where active is true and customer_selection_code is not null;

commit;

notify pgrst, 'reload schema';

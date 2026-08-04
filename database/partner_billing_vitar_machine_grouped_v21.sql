-- VITAR, s.r.o. · Tišnov · měsíční vyúčtování dvou kávových automatů.
-- Pravidla byla ověřena proti fakturám FV26-0137 a FV26-0152:
--   oba kávové automaty = 4,13 Kč bez DPH za vydanou porci,
--   každý automat tvoří samostatný řádek faktury,
--   potravinový automat EV 78 se do tohoto vyúčtování nezahrnuje,
--   DPH 21 %, výsledná částka se zaokrouhluje na celé Kč.

begin;

alter table public.partner_billing_profiles
  add column if not exists itemized_grouping text not null default 'product',
  add column if not exists machine_line_descriptions jsonb not null default '{}'::jsonb,
  add column if not exists billing_data_complete_from date,
  add column if not exists billing_data_note text;

alter table public.partner_billing_profiles
  drop constraint if exists partner_billing_profiles_itemized_grouping_check;

alter table public.partner_billing_profiles
  add constraint partner_billing_profiles_itemized_grouping_check
  check (itemized_grouping in ('product', 'machine'));

alter table public.partner_billing_profiles
  drop constraint if exists partner_billing_profiles_machine_line_descriptions_check;

alter table public.partner_billing_profiles
  add constraint partner_billing_profiles_machine_line_descriptions_check
  check (jsonb_typeof(machine_line_descriptions) = 'object');

do $$
declare
  v_location_id constant bigint := 60;
  v_lei_machine_id constant bigint := 60;
  v_luce_machine_id constant bigint := 66;
  v_note constant text := 'VITAR: sazba 4,13 Kč bez DPH za vydanou porci; ověřeno podle FV26-0137 a FV26-0152.';
begin
  if not exists (
    select 1 from public.locations
    where id = v_location_id and name = 'Vitar' and city = 'Tišnov'
  ) then
    raise exception 'Provozovna Vitar / Tišnov nebyla nalezena na očekávaném záznamu.';
  end if;

  if not exists (
    select 1 from public.machines
    where id = v_lei_machine_id
      and location_id = v_location_id
      and evidence_number = 80
      and machine_type = 'Coffee'
  ) then
    raise exception 'Kávový automat Vitar EV 80 nebyl nalezen na očekávaném záznamu.';
  end if;

  if not exists (
    select 1 from public.machines
    where id = v_luce_machine_id
      and location_id = v_location_id
      and evidence_number = 86
      and machine_type = 'Coffee'
  ) then
    raise exception 'Kávový automat Vitar EV 86 nebyl nalezen na očekávaném záznamu.';
  end if;

  if (
    select count(*)
    from public.business_contacts
    where contact_type in ('customer', 'both')
      and active = true
      and public.olvend_contact_norm(name) = public.olvend_contact_norm('VITAR, s.r.o.')
  ) <> 1 then
    raise exception 'Odběratel VITAR, s.r.o. nebyl nalezen jednoznačně.';
  end if;

  insert into public.machine_planogram_slots (
    machine_id, slot_code, product_name, product_sku, price_czk, dex_price_czk,
    active, sort_order, telemetry_key, customer_price_czk,
    settlement_type, settlement_amount_czk, settlement_partner,
    settlement_billing_enabled, settlement_note,
    subsidy_amount_czk, subsidy_payer, subsidy_billing_enabled, subsidy_note,
    substitution_policy, operator_instruction, note
  )
  values (
    v_lei_machine_id, '0', 'Telemetrie prodej káva', '252', 10, 10,
    true, 0, '0', 10,
    'subsidy_receivable', 4.13, 'VITAR, s.r.o.', true, v_note,
    4.13, 'VITAR, s.r.o.', true, v_note,
    'exact', 'Souhrnný DEX čítač; neodečítat konkrétní recepturu.',
    'Souhrnný telemetrický kanál EV 80 / TID 592150. Doplněn po ověření skutečného DEX formátu.'
  )
  on conflict (machine_id, slot_code) do update set
    product_name = excluded.product_name,
    product_sku = excluded.product_sku,
    price_czk = excluded.price_czk,
    dex_price_czk = excluded.dex_price_czk,
    active = true,
    sort_order = excluded.sort_order,
    telemetry_key = excluded.telemetry_key,
    customer_price_czk = excluded.customer_price_czk,
    settlement_type = excluded.settlement_type,
    settlement_amount_czk = excluded.settlement_amount_czk,
    settlement_partner = excluded.settlement_partner,
    settlement_billing_enabled = excluded.settlement_billing_enabled,
    settlement_note = excluded.settlement_note,
    subsidy_amount_czk = excluded.subsidy_amount_czk,
    subsidy_payer = excluded.subsidy_payer,
    subsidy_billing_enabled = excluded.subsidy_billing_enabled,
    subsidy_note = excluded.subsidy_note,
    substitution_policy = excluded.substitution_policy,
    operator_instruction = excluded.operator_instruction,
    note = excluded.note,
    updated_at = now();

  if (
    select count(*)
    from public.machine_planogram_slots
    where machine_id = v_lei_machine_id
      and active = true
      and slot_code ~ '^([0-9]|1[0-9]|2[0-1])$'
  ) <> 22 then
    raise exception 'Automat Vitar EV 80 nemá očekávaných 21 voleb a souhrnný kanál 0.';
  end if;

  if (
    select count(*)
    from public.machine_planogram_slots
    where machine_id = v_luce_machine_id
      and active = true
      and slot_code ~ '^([0-9]|1[0-9]|2[0-4])$'
  ) <> 25 then
    raise exception 'Automat Vitar EV 86 nemá očekávaných 24 voleb a souhrnný kanál 0.';
  end if;

  update public.machine_planogram_slots
  set
    settlement_type = 'none',
    settlement_amount_czk = 0,
    settlement_partner = null,
    settlement_billing_enabled = false,
    settlement_note = null,
    subsidy_amount_czk = 0,
    subsidy_payer = null,
    subsidy_billing_enabled = false,
    subsidy_note = null,
    updated_at = now()
  where machine_id in (v_lei_machine_id, v_luce_machine_id)
    and active = true;

  update public.machine_planogram_slots
  set
    settlement_type = 'subsidy_receivable',
    settlement_amount_czk = 4.13,
    settlement_partner = 'VITAR, s.r.o.',
    settlement_billing_enabled = true,
    settlement_note = v_note,
    subsidy_amount_czk = 4.13,
    subsidy_payer = 'VITAR, s.r.o.',
    subsidy_billing_enabled = true,
    subsidy_note = v_note,
    updated_at = now()
  where machine_id in (v_lei_machine_id, v_luce_machine_id)
    and active = true
    and slot_code = '0';

  update public.machine_coffee_buttons
  set
    settlement_type = 'none',
    settlement_amount_czk = 0,
    settlement_partner = null,
    settlement_billing_enabled = false,
    settlement_note = null,
    updated_at = now()
  where machine_id in (v_lei_machine_id, v_luce_machine_id)
    and active = true;
end
$$;

with ordered_counters as (
  select
    ingest.id as ingest_id,
    ingest.dex_read_datetime,
    (regexp_match(
      ingest.raw_dex,
      E'PA1\\*0\\*[^\\r\\n]*\\r?\\nPA2\\*([^*\\r\\n]+)\\*'
    ))[1]::numeric as total_count,
    lag((regexp_match(
      ingest.raw_dex,
      E'PA1\\*0\\*[^\\r\\n]*\\r?\\nPA2\\*([^*\\r\\n]+)\\*'
    ))[1]::numeric) over (order by ingest.dex_read_datetime, ingest.id) as previous_total
  from public.telemetry_dex_ingests ingest
  where ingest.provider = 'IMA'
    and ingest.device_id = '592150'
    and ingest.status = 'parsed'
), recovered as (
  insert into public.telemetry_sales_events (
    provider, ingest_id, machine_id, planogram_slot_id, selection_code,
    product_name, product_sku, quantity, cash_quantity, cashless_quantity,
    unknown_payment_quantity, unit_price_czk, total_amount_czk, cash_amount_czk,
    cashless_amount_czk, unknown_payment_amount_czk, source_event_at,
    source_event_key, event_part
  )
  select
    'IMA-recovery', counter.ingest_id, 60, slot.id, '0',
    slot.product_name, slot.product_sku,
    greatest(0, counter.total_count - counter.previous_total),
    0, 0, greatest(0, counter.total_count - counter.previous_total),
    slot.customer_price_czk,
    round(greatest(0, counter.total_count - counter.previous_total) * slot.customer_price_czk, 2),
    0, 0,
    round(greatest(0, counter.total_count - counter.previous_total) * slot.customer_price_czk, 2),
    counter.dex_read_datetime,
    'vitar-ev80-aggregate-recovery-' || counter.ingest_id,
    1
  from ordered_counters counter
  join public.machine_planogram_slots slot
    on slot.machine_id = 60 and slot.slot_code = '0' and slot.active = true
  where counter.previous_total is not null
    and counter.total_count > counter.previous_total
  on conflict (provider, source_event_key, event_part)
    where source_event_key is not null
  do nothing
  returning ingest_id, planogram_slot_id, quantity, source_event_at
)
insert into public.telemetry_financial_settlements (
  provider, ingest_id, machine_id, planogram_slot_id, selection_code,
  product_name, product_sku, settlement_type, direction, quantity,
  amount_per_unit_czk, total_amount_czk, customer_price_czk, partner,
  billing_enabled, status, source_event_at, note
)
select
  'IMA-recovery', recovered.ingest_id, 60, recovered.planogram_slot_id, '0',
  slot.product_name, slot.product_sku, 'subsidy_receivable', 'receivable',
  recovered.quantity, 4.13, round(recovered.quantity * 4.13, 2),
  slot.customer_price_czk, 'VITAR, s.r.o.', true, 'pending',
  recovered.source_event_at,
  'Zpětně dopočteno z navazujících souhrnných IMA/DEX čítačů EV 80.'
from recovered
join public.machine_planogram_slots slot on slot.id = recovered.planogram_slot_id
on conflict (provider, ingest_id, machine_id, planogram_slot_id, selection_code, settlement_type)
do nothing;

insert into public.telemetry_planogram_counters (
  provider, machine_id, planogram_slot_id, selection_code,
  last_total_count, last_cash_count, last_cashless_count,
  last_event_at, last_ingest_id
)
select
  'IMA', 60, slot.id, '0', latest.total_count, 0, 0,
  latest.dex_read_datetime, latest.ingest_id
from public.machine_planogram_slots slot
cross join lateral (
  select
    ingest.id as ingest_id,
    ingest.dex_read_datetime,
    (regexp_match(
      ingest.raw_dex,
      E'PA1\\*0\\*[^\\r\\n]*\\r?\\nPA2\\*([^*\\r\\n]+)\\*'
    ))[1]::numeric as total_count
  from public.telemetry_dex_ingests ingest
  where ingest.provider = 'IMA'
    and ingest.device_id = '592150'
    and ingest.status = 'parsed'
  order by ingest.dex_read_datetime desc, ingest.id desc
  limit 1
) latest
where slot.machine_id = 60 and slot.slot_code = '0' and slot.active = true
on conflict (provider, machine_id, planogram_slot_id, selection_code) do update set
  last_total_count = excluded.last_total_count,
  last_cash_count = excluded.last_cash_count,
  last_cashless_count = excluded.last_cashless_count,
  last_event_at = excluded.last_event_at,
  last_ingest_id = excluded.last_ingest_id,
  updated_at = now();

update public.location_financial_rules
set
  scope_type = 'location',
  settlement_type = 'per_unit',
  direction = 'from_partner',
  amount = 4.13,
  currency = 'CZK',
  unit = 'porce',
  periodicity = 'monthly',
  note = 'VITAR: 4,13 Kč bez DPH za každou vydanou porci ze dvou kávových automatů.',
  updated_at = now()
where location_id = 60
  and direction = 'from_partner'
  and settlement_type in ('subsidy', 'per_unit')
  and coalesce(valid_to, date '9999-12-31') >= date '2026-01-01';

insert into public.location_financial_rules (
  location_id, scope_type, settlement_type, direction, amount, currency,
  unit, periodicity, valid_from, note
)
select
  60, 'location', 'per_unit', 'from_partner', 4.13, 'CZK',
  'porce', 'monthly', date '2026-01-01',
  'VITAR: 4,13 Kč bez DPH za každou vydanou porci ze dvou kávových automatů.'
where not exists (
  select 1
  from public.location_financial_rules rule
  where rule.location_id = 60
    and rule.direction = 'from_partner'
    and rule.settlement_type in ('subsidy', 'per_unit')
    and coalesce(rule.valid_to, date '9999-12-31') >= date '2026-01-01'
);

insert into public.partner_billing_profiles (
  location_id,
  business_contact_id,
  device_label,
  invoice_description_template,
  vat_rate,
  rounding_mode,
  customer_order_number,
  email_recipient,
  attachment_mode,
  billing_scope,
  product_category_filter,
  quantity_label,
  quantity_unit,
  unit_vat_rate,
  fixed_monthly_amount,
  fixed_vat_rate,
  fixed_description_template,
  itemized_grouping,
  machine_line_descriptions,
  billing_data_complete_from,
  billing_data_note,
  active
)
select
  60,
  contact.id,
  'Lei 600 + Luce X2',
  'Provoz kávových automatů - {month}/{year}',
  21,
  'integer',
  null,
  'fakturace@vitar.cz',
  'optional',
  'settlement_rules',
  null,
  'Vydané porce',
  'porcí',
  21,
  0,
  21,
  null,
  'machine',
  jsonb_build_object(
    '60', 'Provoz kávového automatu č. 2 Lei 600 (vrchní automat) - {month}/{year}',
    '66', 'Provoz kávového automatu č. 1 Luce X2 (spodní automat) - {month}/{year}'
  ),
  date '2026-07-28',
  'EV 80 má ověřená přímá IMA/DEX data až od 28. 7. 2026; pro dřívější období je nutné doplnit historický počet porcí.',
  true
from public.business_contacts contact
where contact.contact_type in ('customer', 'both')
  and contact.active = true
  and public.olvend_contact_norm(contact.name) = public.olvend_contact_norm('VITAR, s.r.o.')
on conflict (location_id) do update set
  business_contact_id = excluded.business_contact_id,
  device_label = excluded.device_label,
  invoice_description_template = excluded.invoice_description_template,
  vat_rate = excluded.vat_rate,
  rounding_mode = excluded.rounding_mode,
  customer_order_number = excluded.customer_order_number,
  email_recipient = excluded.email_recipient,
  attachment_mode = excluded.attachment_mode,
  billing_scope = excluded.billing_scope,
  product_category_filter = excluded.product_category_filter,
  quantity_label = excluded.quantity_label,
  quantity_unit = excluded.quantity_unit,
  unit_vat_rate = excluded.unit_vat_rate,
  fixed_monthly_amount = excluded.fixed_monthly_amount,
  fixed_vat_rate = excluded.fixed_vat_rate,
  fixed_description_template = excluded.fixed_description_template,
  itemized_grouping = excluded.itemized_grouping,
  machine_line_descriptions = excluded.machine_line_descriptions,
  billing_data_complete_from = excluded.billing_data_complete_from,
  billing_data_note = excluded.billing_data_note,
  active = true,
  updated_at = now();

commit;

select
  m.evidence_number,
  count(*) as billable_slots,
  min(s.settlement_amount_czk) as min_rate,
  max(s.settlement_amount_czk) as max_rate
from public.machine_planogram_slots s
join public.machines m on m.id = s.machine_id
where s.machine_id in (60, 66)
  and s.active = true
  and s.settlement_billing_enabled = true
group by m.evidence_number
order by m.evidence_number;

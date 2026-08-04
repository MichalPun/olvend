-- VITAR, s.r.o. · doplnění července 2026 z historického měsíčního exportu.
-- Zdroj: telemetry-sales-by-machine (1).xlsx, období 01/07/2026–31/07/2026.
-- Pokyn uživatele: historické počty se sčítají s výdeji po přechodu na naši IMA/DEX telemetrii.
-- Výsledné fakturační počty:
--   EV 80 Lei 600: 495 historický přenos + 64 IMA/DEX = 559 porcí,
--   EV 86 Luce X2: 838 historický report + 90 po přechodu = 928 porcí.

begin;

do $$
declare
  v_machine_id constant bigint := 60;
  v_slot_id bigint;
  v_event_at constant timestamptz := timestamptz '2026-07-27 12:00:00+02';
  v_source_key constant text := 'vitar-ev80-2026-07-historical-transfer';
begin
  select slot.id into strict v_slot_id
  from public.machine_planogram_slots slot
  where slot.machine_id = v_machine_id
    and slot.slot_code = '0'
    and slot.active = true;

  update public.telemetry_sales_events
  set
    ingest_id = null,
    machine_id = v_machine_id,
    planogram_slot_id = v_slot_id,
    selection_code = '0',
    product_name = 'Telemetrie prodej káva',
    product_sku = '252',
    quantity = 495,
    cash_quantity = 0,
    cashless_quantity = 0,
    unknown_payment_quantity = 495,
    unit_price_czk = 4.13,
    total_amount_czk = 2044.35,
    cash_amount_czk = 0,
    cashless_amount_czk = 0,
    unknown_payment_amount_czk = 2044.35,
    source_event_at = v_event_at,
    source_location_name = 'Tišnov_Vitar KÁVA',
    source_machine_name = '80 LEI 600 Touch',
    event_part = 1
  where provider = 'Historical-transfer'
    and source_event_key = v_source_key;

  if not found then
    insert into public.telemetry_sales_events (
      provider, ingest_id, machine_id, planogram_slot_id, selection_code,
      product_name, product_sku, quantity, cash_quantity, cashless_quantity,
      unknown_payment_quantity, unit_price_czk, total_amount_czk, cash_amount_czk,
      cashless_amount_czk, unknown_payment_amount_czk, source_event_at,
      source_event_key, source_location_name, source_machine_name, event_part
    ) values (
      'Historical-transfer', null, v_machine_id, v_slot_id, '0',
      'Telemetrie prodej káva', '252', 495, 0, 0,
      495, 4.13, 2044.35, 0,
      0, 2044.35, v_event_at,
      v_source_key, 'Tišnov_Vitar KÁVA', '80 LEI 600 Touch', 1
    );
  end if;

  update public.telemetry_financial_settlements
  set
    ingest_id = null,
    machine_id = v_machine_id,
    planogram_slot_id = v_slot_id,
    selection_code = '0',
    product_name = 'Telemetrie prodej káva',
    product_sku = '252',
    settlement_type = 'subsidy_receivable',
    direction = 'receivable',
    quantity = 495,
    amount_per_unit_czk = 4.13,
    total_amount_czk = 2044.35,
    customer_price_czk = 10,
    partner = 'VITAR, s.r.o.',
    billing_enabled = true,
    status = 'pending',
    source_event_at = v_event_at,
    note = 'Historický přenos července 2026 z telemetry-sales-by-machine (1).xlsx; 495 porcí EV 80.'
  where provider = 'Historical-transfer'
    and machine_id = v_machine_id
    and planogram_slot_id = v_slot_id
    and selection_code = '0'
    and settlement_type = 'subsidy_receivable'
    and source_event_at = v_event_at;

  if not found then
    insert into public.telemetry_financial_settlements (
      provider, ingest_id, machine_id, planogram_slot_id, selection_code,
      product_name, product_sku, settlement_type, direction, quantity,
      amount_per_unit_czk, total_amount_czk, customer_price_czk, partner,
      billing_enabled, status, source_event_at, note
    ) values (
      'Historical-transfer', null, v_machine_id, v_slot_id, '0',
      'Telemetrie prodej káva', '252', 'subsidy_receivable', 'receivable', 495,
      4.13, 2044.35, 10, 'VITAR, s.r.o.',
      true, 'pending', v_event_at,
      'Historický přenos července 2026 z telemetry-sales-by-machine (1).xlsx; 495 porcí EV 80.'
    );
  end if;
end
$$;

update public.partner_billing_profiles
set
  billing_data_complete_from = date '2026-07-01',
  billing_data_note = 'Červenec 2026 ověřen proti telemetry-sales-by-machine (1).xlsx: EV 80 = 495 historický přenos + 64 IMA/DEX, EV 86 = 838 historický report + 90 po přechodu. Od srpna běží přímá IMA/DEX telemetrie.',
  updated_at = now()
where location_id = 60
  and active = true;

do $$
declare
  v_ev80 numeric;
  v_ev86 numeric;
begin
  with july_rows as (
    select event.*,
      min(event.source_event_at) filter (where lower(event.provider) like '%ima%')
        over (partition by event.machine_id) as first_ima_at
    from public.telemetry_sales_events event
    where event.machine_id in (60, 66)
      and event.source_event_at >= timestamptz '2026-07-01 00:00:00+02'
      and event.source_event_at < timestamptz '2026-08-01 00:00:00+02'
  ), authoritative as (
    select *
    from july_rows
    where lower(provider) like '%ima%'
       or first_ima_at is null
       or source_event_at < first_ima_at
  )
  select
    coalesce(sum(quantity) filter (where machine_id = 60), 0),
    coalesce(sum(quantity) filter (where machine_id = 66), 0)
  into v_ev80, v_ev86
  from authoritative;

  if v_ev80 <> 559 or v_ev86 <> 928 then
    raise exception 'Kontrola Vitar červenec selhala: EV80 %, EV86 %; očekáváno 559 a 928.', v_ev80, v_ev86;
  end if;

  if not exists (
    select 1
    from public.partner_billing_profiles
    where location_id = 60
      and active = true
      and billing_data_complete_from = date '2026-07-01'
  ) then
    raise exception 'Profil Vitar nebyl odblokován pro červenec 2026.';
  end if;
end
$$;

commit;

with july_rows as (
  select event.*,
    min(event.source_event_at) filter (where lower(event.provider) like '%ima%')
      over (partition by event.machine_id) as first_ima_at
  from public.telemetry_sales_events event
  where event.machine_id in (60, 66)
    and event.source_event_at >= timestamptz '2026-07-01 00:00:00+02'
    and event.source_event_at < timestamptz '2026-08-01 00:00:00+02'
), authoritative as (
  select *
  from july_rows
  where lower(provider) like '%ima%'
     or first_ima_at is null
     or source_event_at < first_ima_at
)
select
  machine.evidence_number,
  sum(authoritative.quantity) as billed_quantity,
  round(sum(authoritative.quantity) * 4.13, 2) as net_amount_czk
from authoritative
join public.machines machine on machine.id = authoritative.machine_id
group by machine.evidence_number
order by machine.evidence_number;

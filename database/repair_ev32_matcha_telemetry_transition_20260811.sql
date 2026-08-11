-- Oprava přechodu telemetrie TID 596507 z EV 29 na EV 32.
-- Čítač volby 8 vzrostl mezi odečty 136121 a 136297 z 227 na 228.

do $$
declare
  v_source_machine_id bigint := 24;
  v_target_machine_id bigint := 27;
  v_source_ingest_id bigint := 136121;
  v_target_ingest_id bigint := 136297;
  v_matcha_slot_id bigint := 2116;
  v_matcha_sale_event_id bigint;
  v_already_repaired boolean;
begin
  if not exists (
    select 1
    from public.telemetry_dex_ingests i
    where i.id = v_source_ingest_id
      and i.device_id = '596507'
      and i.raw_dex like '%PA1*8*0%PA2*227*7200*227*7200%'
  ) then
    raise exception 'Výchozí DEX odečet 136121 neobsahuje očekávaný čítač volby 8 = 227.';
  end if;

  if not exists (
    select 1
    from public.telemetry_dex_ingests i
    where i.id = v_target_ingest_id
      and i.device_id = '596507'
      and i.raw_dex like '%PA1*8*0%PA2*228*7200*228*7200%'
  ) then
    raise exception 'Cílový DEX odečet 136297 neobsahuje očekávaný čítač volby 8 = 228.';
  end if;

  if not exists (
    select 1
    from public.machine_planogram_slots s
    where s.id = v_matcha_slot_id
      and s.machine_id = v_target_machine_id
      and s.slot_code = '8'
      and s.product_sku = '267'
      and lower(s.product_name) like '%matcha%malina%'
  ) then
    raise exception 'Volba 8 EV 32 neodpovídá Matcha Latte Malina 180 ml.';
  end if;

  -- Telemetrické sloty musí mít stejné partnerské nastavení jako zrcadlená tlačítka.
  update public.machine_planogram_slots slot
  set
    customer_price_czk = button.customer_price_czk,
    price_czk = button.sale_price_czk,
    dex_price_czk = button.sale_price_czk,
    settlement_type = button.settlement_type,
    settlement_amount_czk = button.settlement_amount_czk,
    settlement_partner = button.settlement_partner,
    settlement_billing_enabled = button.settlement_billing_enabled,
    settlement_note = button.settlement_note,
    subsidy_amount_czk = button.settlement_amount_czk,
    subsidy_payer = button.settlement_partner,
    subsidy_billing_enabled = button.settlement_billing_enabled,
    subsidy_note = button.settlement_note,
    updated_at = now()
  from public.machine_coffee_buttons button
  where slot.machine_id = v_target_machine_id
    and button.machine_id = v_target_machine_id
    and slot.active = true
    and button.active = true
    and slot.slot_code = button.selection_code;

  -- Matcha 180 ml: partner hradí přesně 10 Kč včetně DPH.
  update public.machine_coffee_buttons
  set
    settlement_amount_czk = 8.264463,
    settlement_partner = 'SPORTISIMO s.r.o.',
    settlement_billing_enabled = true,
    settlement_note = 'SPORTISIMO: partnerská sazba 10 Kč včetně DPH (přesný základ 10 / 1,21).',
    updated_at = now()
  where machine_id = v_target_machine_id
    and active = true
    and selection_code = '8'
    and product_sku = '267';

  update public.machine_planogram_slots
  set
    settlement_amount_czk = 8.264463,
    settlement_partner = 'SPORTISIMO s.r.o.',
    settlement_billing_enabled = true,
    settlement_note = 'SPORTISIMO: partnerská sazba 10 Kč včetně DPH (přesný základ 10 / 1,21).',
    subsidy_amount_czk = 8.264463,
    subsidy_payer = 'SPORTISIMO s.r.o.',
    subsidy_billing_enabled = true,
    subsidy_note = 'SPORTISIMO: partnerská sazba 10 Kč včetně DPH (přesný základ 10 / 1,21).',
    updated_at = now()
  where id = v_matcha_slot_id
    and machine_id = v_target_machine_id
    and active = true
    and slot_code = '8'
    and product_sku = '267';

  select exists (
    select 1
    from public.telemetry_sales_events event
    where event.provider = 'IMA'
      and event.source_event_key = 'ev32-transition-596507-20260811-selection8'
      and event.event_part = 1
  ) into v_already_repaired;

  if not v_already_repaired then

  -- Přenes poslední ověřený čítač stejného fyzického automatu na nové evidenční číslo.
  insert into public.telemetry_planogram_counters (
    provider,
    machine_id,
    planogram_slot_id,
    selection_code,
    last_total_count,
    last_cash_count,
    last_cashless_count,
    last_event_at,
    last_ingest_id
  )
  select
    'IMA',
    v_target_machine_id,
    target_slot.id,
    target_slot.slot_code,
    source_counter.last_total_count,
    source_counter.last_cash_count,
    source_counter.last_cashless_count,
    source_counter.last_event_at,
    source_counter.last_ingest_id
  from public.machine_planogram_slots target_slot
  join public.machine_planogram_slots source_slot
    on source_slot.machine_id = v_source_machine_id
   and source_slot.active = true
   and source_slot.slot_code = target_slot.slot_code
  join public.telemetry_planogram_counters source_counter
    on source_counter.provider = 'IMA'
   and source_counter.machine_id = v_source_machine_id
   and source_counter.planogram_slot_id = source_slot.id
   and source_counter.selection_code = source_slot.slot_code
   and source_counter.last_ingest_id = v_source_ingest_id
  where target_slot.machine_id = v_target_machine_id
    and target_slot.active = true
  on conflict (provider, machine_id, planogram_slot_id, selection_code) do update
  set
    last_total_count = excluded.last_total_count,
    last_cash_count = excluded.last_cash_count,
    last_cashless_count = excluded.last_cashless_count,
    last_event_at = excluded.last_event_at,
    last_ingest_id = excluded.last_ingest_id,
    updated_at = now();

  -- Jediný prodej v přechodovém okně: volba 8, Matcha 180 ml, zákaznická cena 0 Kč.
  insert into public.telemetry_sales_events (
    provider,
    ingest_id,
    machine_id,
    planogram_slot_id,
    selection_code,
    product_name,
    product_sku,
    quantity,
    cash_quantity,
    cashless_quantity,
    free_vend_quantity,
    unknown_payment_quantity,
    unpaid_dispense_quantity,
    unit_price_czk,
    total_amount_czk,
    cash_amount_czk,
    cashless_amount_czk,
    unknown_payment_amount_czk,
    source_event_at,
    source_event_key,
    event_part
  ) values (
    'IMA',
    v_target_ingest_id,
    v_target_machine_id,
    v_matcha_slot_id,
    '8',
    'Matcha Latte Malina 180 ml',
    '267',
    1,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    timestamptz '2026-08-11 05:26:47+00',
    'ev32-transition-596507-20260811-selection8',
    1
  )
  on conflict (provider, source_event_key, event_part)
    where source_event_key is not null
  do update set
    quantity = excluded.quantity,
    free_vend_quantity = excluded.free_vend_quantity,
    unit_price_czk = excluded.unit_price_czk,
    total_amount_czk = excluded.total_amount_czk
  returning id into v_matcha_sale_event_id;

  perform public.apply_telemetry_coffee_depletion(array[v_matcha_sale_event_id]);
  perform public.apply_telemetry_stock_depletion(array[v_matcha_sale_event_id]);

  -- Poslední zpracovaný stav je 228; ostatní volby se mezi odečty nezměnily.
  update public.telemetry_planogram_counters
  set
    last_total_count = 228,
    last_cash_count = 0,
    last_cashless_count = 0,
    last_event_at = timestamptz '2026-08-11 05:26:47+00',
    last_ingest_id = v_target_ingest_id,
    updated_at = now()
  where provider = 'IMA'
    and machine_id = v_target_machine_id
    and planogram_slot_id = v_matcha_slot_id
    and selection_code = '8';

  update public.telemetry_dex_ingests
  set status = 'parsed', parse_error = null, updated_at = now()
  where id in (136181, 136240, 136297)
    and device_id = '596507'
    and parse_error = 'previous is not defined';
  end if;
end
$$;

select
  event.id,
  machine.evidence_number,
  event.selection_code,
  event.product_name,
  event.quantity,
  event.free_vend_quantity,
  event.total_amount_czk,
  event.source_event_at
from public.telemetry_sales_events event
join public.machines machine on machine.id = event.machine_id
where event.source_event_key = 'ev32-transition-596507-20260811-selection8';

-- Restore the exact day-level IMA payment credit that was received before the
-- product counters caught up while the old reconciliation query was timing out.
-- Free/partner vends are excluded because their DEX cash counters are expected
-- to remain outside booked cash revenue.
begin;

create table if not exists public.telemetry_state_credit_backup_v26_20260806 (
  machine_id bigint primary key,
  row_data jsonb not null,
  backed_up_at timestamptz not null default now()
);

create temporary table ima_payment_credit_seed on commit drop as
with links as (
  select distinct on (link.machine_id)
    link.machine_id,
    link.external_machine_id as device_id
  from public.machine_external_links link
  where link.provider = 'IMA'
    and link.telemetry_enabled = true
    and link.machine_id in (16, 31, 14, 91, 81, 25, 60, 32, 23, 90, 66)
  order by link.machine_id, link.id
), ingest_sequence as (
  select
    ingest.device_id,
    coalesce(ingest.dex_read_datetime, ingest.transaction_time, ingest.created_at) as event_at,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint
      - lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as cash_amount,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint
      - lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as cash_quantity,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint
      - lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as card_amount,
    greatest(0,
      (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint
      - lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
        over (partition by ingest.device_id order by ingest.id)
    ) as card_quantity
  from public.telemetry_dex_ingests ingest
  join links link using (device_id)
  where ingest.provider = 'IMA'
), payments as (
  select
    link.machine_id,
    link.device_id,
    coalesce(sum(sequence.cash_quantity), 0) as dex_cash_quantity,
    coalesce(sum(sequence.cash_amount), 0) as dex_cash_amount,
    coalesce(sum(sequence.card_quantity), 0) as dex_card_quantity,
    coalesce(sum(sequence.card_amount), 0) as dex_card_amount,
    max(sequence.event_at) as latest_event_at
  from links link
  left join ingest_sequence sequence
    on sequence.device_id = link.device_id
   and sequence.event_at >= timestamptz '2026-08-05 22:00:00+00'
   and sequence.event_at <  timestamptz '2026-08-06 22:00:00+00'
  group by link.machine_id, link.device_id
), sales as (
  select
    links.machine_id,
    coalesce(sum(sale.free_vend_quantity), 0) as free_vends,
    coalesce(sum(sale.cash_quantity), 0) as saved_cash_quantity,
    coalesce(round(sum(sale.cash_amount_czk) * 100), 0) as saved_cash_amount,
    coalesce(sum(sale.cashless_quantity), 0) as saved_card_quantity,
    coalesce(round(sum(sale.cashless_amount_czk) * 100), 0) as saved_card_amount,
    coalesce(sum(sale.unpaid_dispense_quantity), 0) as pending
  from links
  left join public.telemetry_sales_events sale
    on sale.machine_id = links.machine_id
   and sale.provider = 'IMA'
   and sale.source_event_at >= timestamptz '2026-08-05 22:00:00+00'
   and sale.source_event_at <  timestamptz '2026-08-06 22:00:00+00'
  group by links.machine_id
), credits as (
  select
    payments.machine_id,
    payments.device_id,
    payments.latest_event_at,
    greatest(0, payments.dex_cash_quantity - sales.saved_cash_quantity)::integer as cash_quantity,
    greatest(0, payments.dex_cash_amount - sales.saved_cash_amount)::bigint as cash_amount,
    greatest(0, payments.dex_card_quantity - sales.saved_card_quantity)::integer as cashless_quantity,
    greatest(0, payments.dex_card_amount - sales.saved_card_amount)::bigint as cashless_amount,
    sales.free_vends,
    sales.pending
  from payments
  join sales using (machine_id)
)
select *
from credits
where free_vends = 0
  and pending = 0
  and cash_quantity + cashless_quantity > 0;

do $$
declare
  v_machines integer;
  v_units integer;
begin
  select count(*), coalesce(sum(cash_quantity + cashless_quantity), 0)
  into v_machines, v_units
  from ima_payment_credit_seed;

  if v_machines <> 11 or v_units <> 70 then
    raise exception 'Expected 70 residual IMA payment units on 11 machines, found % units on % machines.',
      v_units, v_machines;
  end if;

  -- Lock only the eleven affected state rows after the read-only calculation;
  -- this keeps normal fleet ingestion running during the expensive DEX scan.
  perform state.machine_id
  from public.machine_telemetry_state state
  join ima_payment_credit_seed seed using (machine_id)
  where state.provider = 'IMA'
  for update of state;

  if exists (
    select 1
    from public.machine_telemetry_state state
    join ima_payment_credit_seed seed using (machine_id)
    where state.provider = 'IMA'
      and state.last_seen_at > seed.latest_event_at
  ) then
    raise exception 'IMA state advanced while the credit seed was calculated; rerun from a fresh snapshot.';
  end if;
end $$;

insert into public.telemetry_state_credit_backup_v26_20260806 (machine_id, row_data)
select state.machine_id, to_jsonb(state)
from public.machine_telemetry_state state
join ima_payment_credit_seed seed using (machine_id)
where state.provider = 'IMA'
on conflict (machine_id) do nothing;

update public.machine_telemetry_state state
set counters_payload = jsonb_set(
      coalesce(state.counters_payload, '{}'::jsonb),
      '{pending_payment_credit}',
      jsonb_build_object(
        'cash_quantity', seed.cash_quantity,
        'cashless_quantity', seed.cashless_quantity,
        'cash_amount', seed.cash_amount,
        'cashless_amount', seed.cashless_amount,
        'captured_at', seed.latest_event_at
      ),
      true
    ),
    updated_at = now()
from ima_payment_credit_seed seed
where state.machine_id = seed.machine_id
  and state.provider = 'IMA';

do $$
declare
  v_units integer;
begin
  select coalesce(sum(
    (state.counters_payload -> 'pending_payment_credit' ->> 'cash_quantity')::integer
    + (state.counters_payload -> 'pending_payment_credit' ->> 'cashless_quantity')::integer
  ), 0)
  into v_units
  from public.machine_telemetry_state state
  join ima_payment_credit_seed seed using (machine_id)
  where state.provider = 'IMA';

  if v_units <> 70 then
    raise exception 'IMA payment credit seed validation failed: stored % of 70 units.', v_units;
  end if;
end $$;

select
  count(*) as seeded_machines,
  sum(cash_quantity + cashless_quantity) as seeded_payment_units,
  sum(cash_amount + cashless_amount) as seeded_amount_hal
from ima_payment_credit_seed;

commit;

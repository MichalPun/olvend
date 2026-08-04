-- EV 80 / TID 592150 was recovered from its aggregate PA2 counter for Vitar billing.
-- The recovery import originally marked every reconstructed vend as unknown even
-- though the adjacent immutable IMA DEX CA2/DA2 counters identify cash and card.
-- Reclassify all 78 recovered rows; no VendSoft data is read or changed.

begin;

lock table public.telemetry_sales_events in share row exclusive mode;

create table if not exists public.telemetry_sales_payment_backup_vitar_20260804
  (like public.telemetry_sales_events including defaults);

create unique index if not exists telemetry_sales_payment_backup_vitar_20260804_id_idx
  on public.telemetry_sales_payment_backup_vitar_20260804 (id);

insert into public.telemetry_sales_payment_backup_vitar_20260804
select sale.*
from public.telemetry_sales_events sale
where sale.provider = 'IMA-recovery'
  and sale.machine_id = 60
  and sale.source_event_key like 'vitar-ev80-aggregate-recovery-%'
on conflict (id) do nothing;

create temporary table vitar_recovery_payment_classification on commit drop as
with ingest_sequence as (
  select
    ingest.id,
    (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint as cash_amount_minor,
    (regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint as cash_quantity,
    (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint as card_amount_minor,
    (regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint as card_quantity,
    lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
      over (order by ingest.id) as previous_cash_amount_minor,
    lag((regexp_match(ingest.raw_dex, 'CA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
      over (order by ingest.id) as previous_cash_quantity,
    lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[1]::bigint)
      over (order by ingest.id) as previous_card_amount_minor,
    lag((regexp_match(ingest.raw_dex, 'DA2[*]([0-9]+)[*]([0-9]+)'))[2]::bigint)
      over (order by ingest.id) as previous_card_quantity
  from public.telemetry_dex_ingests ingest
  where ingest.provider = 'IMA'
    and ingest.device_id = '592150'
    and ingest.status = 'parsed'
), counter_deltas as (
  select
    sale.id as sale_id,
    sale.ingest_id,
    sale.source_event_at,
    sale.quantity::integer as sale_quantity,
    greatest(0, sequence.cash_quantity - sequence.previous_cash_quantity)::integer as cash_quantity_delta,
    greatest(0, sequence.cash_amount_minor - sequence.previous_cash_amount_minor)::bigint as cash_amount_delta_minor,
    greatest(0, sequence.card_quantity - sequence.previous_card_quantity)::integer as card_quantity_delta,
    greatest(0, sequence.card_amount_minor - sequence.previous_card_amount_minor)::bigint as card_amount_delta_minor
  from public.telemetry_sales_events sale
  join ingest_sequence sequence on sequence.id = sale.ingest_id
  where sale.provider = 'IMA-recovery'
    and sale.machine_id = 60
    and sale.source_event_key like 'vitar-ev80-aggregate-recovery-%'
), assigned_quantities as (
  select
    delta.*,
    least(delta.sale_quantity, delta.cash_quantity_delta) as assigned_cash_quantity,
    delta.sale_quantity - least(delta.sale_quantity, delta.cash_quantity_delta) as assigned_card_quantity
  from counter_deltas delta
)
select
  assigned.*,
  case
    when assigned.cash_quantity_delta = 0 then 0
    else round(
      assigned.cash_amount_delta_minor::numeric
      * assigned.assigned_cash_quantity
      / assigned.cash_quantity_delta
    )::bigint
  end as assigned_cash_amount_minor,
  case
    when assigned.card_quantity_delta = 0 then 0
    else round(
      assigned.card_amount_delta_minor::numeric
      * assigned.assigned_card_quantity
      / assigned.card_quantity_delta
    )::bigint
  end as assigned_card_amount_minor
from assigned_quantities assigned;

do $$
declare
  source_rows integer;
  source_quantity numeric;
  source_unknown numeric;
  uncovered_rows integer;
begin
  select count(*), coalesce(sum(quantity), 0), coalesce(sum(unknown_payment_quantity), 0)
  into source_rows, source_quantity, source_unknown
  from public.telemetry_sales_events
  where provider = 'IMA-recovery'
    and machine_id = 60
    and source_event_key like 'vitar-ev80-aggregate-recovery-%';

  if source_rows <> 78 or source_quantity <> 109 or source_unknown not in (0, 109) then
    raise exception 'Unexpected Vitar recovery source: rows %, quantity %, unknown %.',
      source_rows, source_quantity, source_unknown;
  end if;

  select count(*)
  into uncovered_rows
  from vitar_recovery_payment_classification
  where cash_quantity_delta + card_quantity_delta < sale_quantity
     or assigned_cash_quantity + assigned_card_quantity <> sale_quantity
     or assigned_card_quantity > card_quantity_delta;

  if uncovered_rows <> 0 then
    raise exception 'Vitar recovery has % rows not covered by adjacent CA2/DA2 counters.', uncovered_rows;
  end if;
end
$$;

update public.telemetry_sales_events sale
set
  cash_quantity = classified.assigned_cash_quantity,
  cashless_quantity = classified.assigned_card_quantity,
  unknown_payment_quantity = 0,
  unpaid_dispense_quantity = 0,
  cash_amount_czk = round(classified.assigned_cash_amount_minor::numeric / 100, 2),
  cashless_amount_czk = round(classified.assigned_card_amount_minor::numeric / 100, 2),
  unknown_payment_amount_czk = 0,
  total_amount_czk = round(
    (classified.assigned_cash_amount_minor + classified.assigned_card_amount_minor)::numeric / 100,
    2
  )
from vitar_recovery_payment_classification classified
where sale.id = classified.sale_id;

do $$
declare
  remaining_unknown numeric;
  broken_rows integer;
  today_unknown numeric;
  today_cash numeric;
  today_card numeric;
begin
  select
    coalesce(sum(unknown_payment_quantity), 0),
    count(*) filter (
      where cash_quantity + cashless_quantity + free_vend_quantity
        + unknown_payment_quantity + unpaid_dispense_quantity <> quantity
    )
  into remaining_unknown, broken_rows
  from public.telemetry_sales_events
  where provider = 'IMA-recovery'
    and machine_id = 60
    and source_event_key like 'vitar-ev80-aggregate-recovery-%';

  select
    coalesce(sum(unknown_payment_quantity), 0),
    coalesce(sum(cash_quantity), 0),
    coalesce(sum(cashless_quantity), 0)
  into today_unknown, today_cash, today_card
  from public.telemetry_sales_events
  where provider in ('IMA', 'IMA-recovery')
    and source_event_at >= timestamptz '2026-08-03 22:00:00+00'
    and source_event_at < timestamptz '2026-08-04 22:00:00+00';

  if remaining_unknown <> 0 or broken_rows <> 0 then
    raise exception 'Vitar recovery validation failed: unknown %, broken rows %.',
      remaining_unknown, broken_rows;
  end if;

  if today_unknown <> 0 or today_cash < 10 or today_card < 12 then
    raise exception 'Current dashboard day is not repaired: unknown %, cash %, card %.',
      today_unknown, today_cash, today_card;
  end if;
end
$$;

commit;

select
  machine.evidence_number,
  sum(sale.quantity) as quantity,
  sum(sale.cash_quantity) as cash_quantity,
  sum(sale.cashless_quantity) as card_quantity,
  sum(sale.unknown_payment_quantity) as unknown_quantity,
  sum(sale.cash_amount_czk) as cash_amount_czk,
  sum(sale.cashless_amount_czk) as card_amount_czk,
  sum(sale.total_amount_czk) as total_amount_czk
from public.telemetry_sales_events sale
join public.machines machine on machine.id = sale.machine_id
where sale.provider in ('IMA', 'IMA-recovery')
  and sale.source_event_at >= timestamptz '2026-08-03 22:00:00+00'
  and sale.source_event_at < timestamptz '2026-08-04 22:00:00+00'
  and sale.machine_id = 60
group by machine.evidence_number;

-- Reclassify 2026-08-03 IMA rows from the actual CA2/DA2 counter deltas.
-- A vend counter without a corresponding payment counter is an unpaid dispense,
-- not revenue and not an unknown payment method.
begin;

create temporary table ima_payment_reclassification_20260803 on commit drop as
with ingest_sequence as (
  select
    d.id,
    d.device_id,
    d.raw_dex,
    lag(d.raw_dex) over (partition by d.provider, d.device_id order by d.id) as previous_raw_dex
  from public.telemetry_dex_ingests d
  where d.provider = 'IMA'
), candidates as (
  select
    sale.id as sale_event_id,
    sale.machine_id,
    sale.quantity,
    sale.unit_price_czk,
    greatest(0,
      split_part(substring(ingest.raw_dex from 'CA2\*[0-9]+\*[0-9]+'), '*', 3)::integer
      - split_part(substring(ingest.previous_raw_dex from 'CA2\*[0-9]+\*[0-9]+'), '*', 3)::integer
    ) as cash_delta,
    greatest(0,
      split_part(substring(ingest.raw_dex from 'DA2\*[0-9]+\*[0-9]+'), '*', 3)::integer
      - split_part(substring(ingest.previous_raw_dex from 'DA2\*[0-9]+\*[0-9]+'), '*', 3)::integer
    ) as card_delta,
    greatest(0,
      split_part(substring(ingest.raw_dex from 'CA2\*[0-9]+\*[0-9]+'), '*', 2)::bigint
      - split_part(substring(ingest.previous_raw_dex from 'CA2\*[0-9]+\*[0-9]+'), '*', 2)::bigint
    ) as cash_amount_delta,
    greatest(0,
      split_part(substring(ingest.raw_dex from 'DA2\*[0-9]+\*[0-9]+'), '*', 2)::bigint
      - split_part(substring(ingest.previous_raw_dex from 'DA2\*[0-9]+\*[0-9]+'), '*', 2)::bigint
    ) as card_amount_delta
  from public.telemetry_sales_events sale
  join ingest_sequence ingest on ingest.id = sale.ingest_id
  where sale.provider = 'IMA'
    and sale.source_event_at >= timestamptz '2026-08-03 00:00:00+00'
    and sale.source_event_at < timestamptz '2026-08-04 00:00:00+00'
    and sale.unknown_payment_quantity > 0
    and sale.cash_quantity = 0
    and sale.cashless_quantity = 0
), cash_allocated as (
  select
    candidates.*,
    case
      -- When both counters move for a single vend, use the amount matching its price.
      when cash_delta > 0 and card_delta > 0 and quantity = 1
        and card_amount_delta = round(unit_price_czk * 100)
        and cash_amount_delta <> round(unit_price_czk * 100)
        then 0::numeric
      else least(quantity, cash_delta)::numeric
    end as paid_cash
  from candidates
), fully_allocated as (
  select
    cash_allocated.*,
    least(quantity - paid_cash, card_delta)::numeric as paid_card
  from cash_allocated
)
select
  sale_event_id,
  machine_id,
  paid_cash,
  paid_card,
  greatest(0, quantity - paid_cash - paid_card)::numeric as unpaid
from fully_allocated;

do $$
declare
  v_rows integer;
  v_attempts numeric;
  v_cash numeric;
  v_card numeric;
  v_unpaid numeric;
begin
  select count(*), sum(paid_cash + paid_card + unpaid), sum(paid_cash), sum(paid_card), sum(unpaid)
  into v_rows, v_attempts, v_cash, v_card, v_unpaid
  from ima_payment_reclassification_20260803;

  if v_rows <> 41 or v_attempts <> 48 or v_cash <> 6 or v_card <> 20 or v_unpaid <> 22 then
    raise exception 'Unexpected IMA classification: rows %, attempts %, cash %, card %, unpaid %',
      v_rows, v_attempts, v_cash, v_card, v_unpaid;
  end if;
end $$;

update public.telemetry_sales_events sale
set
  cash_quantity = correction.paid_cash,
  cashless_quantity = correction.paid_card,
  unknown_payment_quantity = 0,
  unpaid_dispense_quantity = correction.unpaid,
  cash_amount_czk = round(correction.paid_cash * sale.unit_price_czk, 2),
  cashless_amount_czk = round(correction.paid_card * sale.unit_price_czk, 2),
  unknown_payment_amount_czk = 0,
  total_amount_czk = round((correction.paid_cash + correction.paid_card) * sale.unit_price_czk, 2)
from ima_payment_reclassification_20260803 correction
where sale.id = correction.sale_event_id;

commit;

select
  m.evidence_number,
  sum(s.quantity) as attempts,
  sum(s.cash_quantity) as cash,
  sum(s.cashless_quantity) as card,
  sum(s.unknown_payment_quantity) as unknown,
  sum(s.unpaid_dispense_quantity) as unpaid
from public.telemetry_sales_events s
join public.machines m on m.id = s.machine_id
where s.source_event_at >= timestamptz '2026-08-03 00:00:00+00'
  and s.source_event_at < timestamptz '2026-08-04 00:00:00+00'
  and m.evidence_number in (65, 78, 86, 90, 99)
group by m.evidence_number
order by m.evidence_number;

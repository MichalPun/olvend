begin;

-- EV 30: the ingest contains one exact CA2 increment of 14 CZK for a
-- three-unit product-counter increment. Only that one unit is provably cash.
update public.telemetry_sales_events
set cash_quantity = 1,
    unknown_payment_quantity = 2,
    cash_amount_czk = 14,
    unknown_payment_amount_czk = 28
where id = 482658
  and machine_id = 25
  and quantity = 3
  and unknown_payment_quantity = 3
  and unit_price_czk = 14;

-- Machine 2: the daily counter difference requires cash 2 / 56 CZK and
-- card 4 / 101 CZK. Prices 24, 20 and 27 are necessarily card and price 26
-- necessarily cash; the two indistinguishable 30 CZK units remain unknown.
update public.telemetry_sales_events
set cashless_quantity = 1,
    unknown_payment_quantity = 0,
    cashless_amount_czk = unit_price_czk,
    unknown_payment_amount_czk = 0
where id in (482683, 482684, 482690)
  and machine_id = 2
  and quantity = 1
  and unknown_payment_quantity = 1;

update public.telemetry_sales_events
set cash_quantity = 1,
    unknown_payment_quantity = 0,
    cash_amount_czk = unit_price_czk,
    unknown_payment_amount_czk = 0
where id = 482687
  and machine_id = 2
  and quantity = 1
  and unknown_payment_quantity = 1
  and unit_price_czk = 26;

-- Machine 70: the missing daily payment totals exactly equal all six unknown
-- units: 28 CZK cash and 246 CZK card (55 + 26 + 3*55).
update public.telemetry_sales_events
set cash_quantity = 1,
    unknown_payment_quantity = 0,
    cash_amount_czk = 28,
    unknown_payment_amount_czk = 0
where id = 482615
  and machine_id = 70
  and quantity = 1
  and unknown_payment_quantity = 1
  and unit_price_czk = 28;

update public.telemetry_sales_events
set cashless_quantity = quantity,
    unknown_payment_quantity = 0,
    cashless_amount_czk = total_amount_czk,
    unknown_payment_amount_czk = 0
where id in (482619, 482625, 482627)
  and machine_id = 70
  and unknown_payment_quantity = quantity;

-- Machine 73: cash target 60 CZK from two units forces the unique 35 CZK unit
-- to cash. The two 25 CZK units remain unknown because their media are not
-- individually distinguishable.
update public.telemetry_sales_events
set cash_quantity = 1,
    unknown_payment_quantity = 0,
    cash_amount_czk = 35,
    unknown_payment_amount_czk = 0
where id = 482744
  and machine_id = 73
  and quantity = 1
  and unknown_payment_quantity = 1
  and unit_price_czk = 35;

commit;

select
  sum(cash_quantity) as cash_quantity,
  sum(cashless_quantity) as cashless_quantity,
  sum(unknown_payment_quantity) as unknown_quantity,
  sum(cash_amount_czk) as cash_amount_czk,
  sum(cashless_amount_czk) as cashless_amount_czk,
  sum(unknown_payment_amount_czk) as unknown_amount_czk
from public.telemetry_sales_events
where id in (482658, 482683, 482684, 482690, 482687, 482615, 482619, 482625, 482627, 482744);

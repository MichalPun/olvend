-- Machine 30 / ingest 23974: payment counters moved only in DA2 (cashless).
-- The old allocation was too strict because DA2 increased by 2 while only 1 mapped product sale was stored.
update public.telemetry_sales_events
set
  cashless_quantity = quantity,
  cashless_amount_czk = total_amount_czk,
  cash_quantity = 0,
  cash_amount_czk = 0,
  unknown_payment_quantity = 0,
  unknown_payment_amount_czk = 0
where id = 520
  and machine_id = 25
  and ingest_id = 23974
  and selection_code = '11';

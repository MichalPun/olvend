begin;

update public.telemetry_sales_events
set cashless_quantity = cashless_quantity + 1,
    unknown_payment_quantity = unknown_payment_quantity - 1,
    cashless_amount_czk = cashless_amount_czk + 14,
    unknown_payment_amount_czk = unknown_payment_amount_czk - 14
where id = 482586
  and machine_id = 25
  and quantity = 1
  and unknown_payment_quantity = 1;

update public.telemetry_sales_events
set cashless_quantity = cashless_quantity + 1,
    unknown_payment_quantity = unknown_payment_quantity - 1,
    cashless_amount_czk = cashless_amount_czk + 14,
    unknown_payment_amount_czk = unknown_payment_amount_czk - 14
where id = 482595
  and machine_id = 25
  and quantity = 2
  and unknown_payment_quantity = 2;

commit;

select id, source_event_at, product_name, quantity,
       cash_quantity, cashless_quantity, unknown_payment_quantity,
       cash_amount_czk, cashless_amount_czk, unknown_payment_amount_czk
from public.telemetry_sales_events
where id in (482586, 482595)
order by id;

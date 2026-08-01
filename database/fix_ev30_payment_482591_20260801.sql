update public.telemetry_sales_events
set cash_quantity=1,
    cashless_quantity=0,
    unknown_payment_quantity=0,
    cash_amount_czk=14,
    cashless_amount_czk=0,
    unknown_payment_amount_czk=0
where id=482591
  and machine_id=25
  and ingest_id=50706
  and quantity=1;

select id,selection_code,product_name,quantity,cash_quantity,cashless_quantity,unknown_payment_quantity,
       cash_amount_czk,cashless_amount_czk,unknown_payment_amount_czk
from public.telemetry_sales_events where id=482591;

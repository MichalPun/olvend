-- VendSoft's temporary transaction report does not reliably identify payment method.
-- Reclassify already imported VendSoft sales without changing quantities, totals or stock.
update public.telemetry_sales_events
set
  cash_quantity = 0,
  cashless_quantity = 0,
  unknown_payment_quantity = quantity,
  cash_amount_czk = null,
  cashless_amount_czk = null,
  unknown_payment_amount_czk = total_amount_czk
where lower(coalesce(provider, '')) = 'vendsoft'
  and (
    coalesce(cash_quantity, 0) <> 0
    or coalesce(cashless_quantity, 0) <> 0
    or coalesce(unknown_payment_quantity, 0) <> coalesce(quantity, 0)
    or cash_amount_czk is not null
    or cashless_amount_czk is not null
    or unknown_payment_amount_czk is distinct from total_amount_czk
  );

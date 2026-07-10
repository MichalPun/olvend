-- Oprava chybne vygenerovane pondelni automaticke nakladky pro Opel Vivaro.
-- Puvodni vypocet odhadoval vsechny kalendarni dny pred cilem, vcetne vikendu bez planovane jizdy.

update mobile_stock_requests
set status = 'cancelled',
    note = concat_ws(
      ' · ',
      nullif(note, ''),
      'Zruseno opravou 10. 7. 2026: nakladka vznikla pred opravou pondelniho vypoctu pro Vivaro a nema skladove pohyby.'
    ),
    updated_at = now()
where id = 180
  and vehicle_id = 2
  and request_type = 'vehicle_load'
  and status in ('requested', 'picking', 'ready')
  and stock_applied_at is null
  and not exists (
    select 1
    from stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id = 'mobile-stock:180'
  );

update vehicle_auto_load_deferred_needs
set status = 'closed',
    closed_at = now(),
    last_reason = concat_ws(
      ' · ',
      nullif(last_reason, ''),
      'Uzavreno opravou 10. 7. 2026: odklad byl nafouknuty chybne zapoctenymi mezidny pred pondelim.'
    ),
    updated_at = now()
where vehicle_id = 2
  and status = 'open'
  and last_deferred_for_date = '2026-07-13';

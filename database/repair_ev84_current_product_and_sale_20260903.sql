begin;

-- EV 84, pozice 25: při návštěvě 571 byla prázdná původní pozice naplněna
-- čtyřmi kusy ATM Trhané Vepřové. Skladový pohyb je správně, ale starší
-- mobilní logika ponechala ve slotu SKU kuřecích stripsů.
update public.machine_planogram_slots
set product_sku = '154',
    product_name = 'ATM Trhané Vepřové',
    planned_product_sku = null,
    planned_product_name = null,
    planned_price_czk = null,
    changeover_old_units = null,
    changeover_new_units = null,
    changeover_started_at = null,
    updated_at = now()
where machine_id = 64
  and slot_code = '25'
  and product_sku = '17'
  and current_units = 3;

-- Jediný prodej po dokončení dnešní výměny byl fyzicky nový produkt.
update public.telemetry_sales_events
set product_sku = '154',
    product_name = 'ATM Trhané Vepřové'
where machine_id = 64
  and selection_code = '25'
  and source_event_at >= '2026-09-03T07:29:00Z'
  and product_sku = '17';

commit;

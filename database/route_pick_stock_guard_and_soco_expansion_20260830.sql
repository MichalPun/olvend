begin;

-- Rozsireni pilotni zameny sortimentu pro trasy 31. 8. 2026.
update machine_planogram_slots
set
  planned_product_name = 'Proteinový suk s vanilkovou příchutí 45g',
  planned_product_sku = 'SOCO-PROTEIN-VANILKA-45',
  planned_price_czk = 18,
  pending_product_id = 205,
  pending_product_name = 'Proteinový suk s vanilkovou příchutí 45g',
  pending_product_sku = 'SOCO-PROTEIN-VANILKA-45',
  pending_price_czk = 18,
  pending_change_effective_date = date '2026-08-31',
  pending_change_mode = 'full_swap',
  pending_change_note = 'Pilot noveho sortimentu: prazdna pozice Twix se od 31. 8. 2026 meni na Proteinovy suk vanilka.',
  changeover_old_units = 0,
  changeover_new_units = 0,
  updated_at = now()
where id = 1643
  and machine_id = 58
  and slot_code = '20'
  and product_sku = '25'
  and current_units = 0;

update machine_planogram_slots
set
  planned_product_name = 'Peanut Extasy tyčinka s arašídovým máslem 45g',
  planned_product_sku = 'SOCO-EXTASY-PEANUT-45',
  planned_price_czk = 21,
  pending_product_id = 203,
  pending_product_name = 'Peanut Extasy tyčinka s arašídovým máslem 45g',
  pending_product_sku = 'SOCO-EXTASY-PEANUT-45',
  pending_price_czk = 21,
  pending_change_effective_date = date '2026-08-31',
  pending_change_mode = 'full_swap',
  pending_change_note = 'Pilot noveho sortimentu: prazdna pozice Kit Kat se od 31. 8. 2026 meni na Peanut Extasy.',
  changeover_old_units = 0,
  changeover_new_units = 0,
  updated_at = now()
where id = 1957
  and machine_id = 79
  and slot_code = '22'
  and product_sku = '27'
  and current_units = 0;

-- Odstraneni nevydatelnych polozek z dosud neprevzatych vychystani.
delete from mobile_stock_request_items
where id in (3287, 3306, 3333)
  and warehouse_picked_at is null;

insert into mobile_stock_request_items (
  request_id, product_id, product_name, sku, unit,
  requested_quantity, prepared_quantity, note, batch_selection_mode
)
select 357, 203, 'Peanut Extasy tyčinka s arašídovým máslem 45g',
       'SOCO-EXTASY-PEANUT-45', 'Karton 30 ks', 1, 1,
       'Zmena sortimentu 31. 8. 2026 · Sportisimo EV 99 · pozice 22 · do evidence 30 ks', 'auto'
where exists (select 1 from mobile_stock_requests where id = 357 and status = 'requested')
  and not exists (select 1 from mobile_stock_request_items where request_id = 357 and product_id = 203);

insert into mobile_stock_request_items (
  request_id, product_id, product_name, sku, unit,
  requested_quantity, prepared_quantity, note, batch_selection_mode
)
select 359, 205, 'Proteinový suk s vanilkovou příchutí 45g',
       'SOCO-PROTEIN-VANILKA-45', 'Karton 30 ks', 1, 1,
       'Zmena sortimentu 31. 8. 2026 · Vitar EV 78 · pozice 20 · do evidence 30 ks', 'auto'
where exists (select 1 from mobile_stock_requests where id = 359 and status = 'requested')
  and not exists (select 1 from mobile_stock_request_items where request_id = 359 and product_id = 205);

commit;

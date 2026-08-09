begin;

-- Inventura #27: šest fyzicky napočítaných položek nepřevzalo expiraci.
-- U každé je v aktuálním zůstatku právě jedna známá datovaná šarže;
-- starý bezešaržový zůstatek proto nesmí blokovat uzavření inventury.
select public.sync_inventory_audit_expiry_counts(27);

delete from public.inventory_audit_expiry_counts
where audit_item_id in (706, 685, 661, 698, 667, 675);

insert into public.inventory_audit_expiry_counts (
  audit_item_id,
  product_id,
  package_id,
  package_count,
  loose_quantity,
  quantity_base_units,
  expiry_date,
  expiry_unknown,
  lot_code
) values
  (706, 10,  null, 0, 1,  1,  date '2027-05-04', false, null),
  (685, 60,  null, 0, 10, 10, date '2026-10-29', false, null),
  (661, 63,  null, 0, 29, 29, date '2028-02-05', false, null),
  (698, 66,  null, 0, 5,  5,  date '2026-10-19', false, null),
  (667, 85,  null, 0, 18, 18, date '2027-01-30', false, null),
  (675, 121, null, 0, 22, 22, date '2028-05-30', false, null);

select public.close_inventory_audit_atomic(27);

commit;

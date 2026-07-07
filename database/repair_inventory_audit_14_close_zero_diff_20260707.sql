begin;

do $$
declare
  audit_id_to_fix bigint := 14;
  totals record;
begin
  select
    coalesce(sum(book_quantity), 0)::numeric(14,3) as book_total,
    coalesce(sum(counted_quantity), 0)::numeric(14,3) as counted_total,
    coalesce(sum(counted_quantity - book_quantity), 0)::numeric(14,3) as diff_total,
    coalesce(sum((counted_quantity - book_quantity) * unit_cost), 0)::numeric(14,2) as diff_value
  into totals
  from inventory_audit_items
  where audit_id = audit_id_to_fix;

  if abs(totals.diff_total) > 0.0001 then
    raise exception 'Inventura % nemá nulový rozdíl: %', audit_id_to_fix, totals.diff_total;
  end if;

  update inventory_audit_items
     set difference_quantity = counted_quantity - book_quantity,
         difference_value = round((counted_quantity - book_quantity) * unit_cost, 2)
   where audit_id = audit_id_to_fix;

  update inventory_audits
     set status = 'closed',
         book_quantity_total = totals.book_total,
         counted_quantity_total = totals.counted_total,
         difference_quantity_total = totals.diff_total,
         difference_value_total = totals.diff_value,
         transfer_confirmed_at = coalesce(transfer_confirmed_at, counted_at, now()),
         evaluated_at = coalesce(evaluated_at, counted_at, now()),
         closed_at = coalesce(closed_at, counted_at, now()),
         evaluation_note = coalesce(evaluation_note, 'Oprava stavu 2026-07-07: inventura měla všechny řádky spočítané s nulovým rozdílem, bez skladového pohybu.')
   where id = audit_id_to_fix
     and status in ('counted', 'transfer_ready', 'evaluated');
end $$;

commit;

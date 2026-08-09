alter table public.inventory_audit_items
  add column if not exists reported_book_quantity numeric,
  add column if not exists reported_difference_quantity numeric,
  add column if not exists reported_difference_value numeric;

-- Preserve the result currently visible before the later evidence and manager review.
-- For already evaluated historical audits this is only a best-effort snapshot;
-- new evaluations store the original mobile result before recalculation.
update public.inventory_audit_items item
set reported_book_quantity = coalesce(item.reported_book_quantity, item.book_quantity),
    reported_difference_quantity = coalesce(item.reported_difference_quantity, item.difference_quantity),
    reported_difference_value = coalesce(item.reported_difference_value, item.difference_value)
where item.counted_at is not null
  and (
    item.reported_book_quantity is null
    or item.reported_difference_quantity is null
    or item.reported_difference_value is null
  );

comment on column public.inventory_audit_items.reported_book_quantity is
  'Účetní stav v okamžiku odeslání fyzického počtu, před pozdější kontrolou evidence.';
comment on column public.inventory_audit_items.reported_difference_quantity is
  'Původní množstevní rozdíl při fyzickém spočítání.';
comment on column public.inventory_audit_items.reported_difference_value is
  'Původní finanční rozdíl při fyzickém spočítání.';

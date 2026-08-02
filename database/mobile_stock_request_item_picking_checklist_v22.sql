begin;

alter table public.mobile_stock_request_items
  add column if not exists warehouse_picked_at timestamp with time zone,
  add column if not exists warehouse_picked_by uuid references public.employees (id) on delete set null;

create index if not exists mobile_stock_request_items_warehouse_picked_idx
  on public.mobile_stock_request_items (request_id, warehouse_picked_at)
  where warehouse_picked_at is not null;

comment on column public.mobile_stock_request_items.warehouse_picked_at is
  'Čas ručního potvrzení, že skladník tento konkrétní řádek fyzicky vychystal.';

comment on column public.mobile_stock_request_items.warehouse_picked_by is
  'Pracovník, který řádek ručně označil jako fyzicky vychystaný.';

commit;

notify pgrst, 'reload schema';

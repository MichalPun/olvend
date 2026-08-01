alter table public.mobile_stock_request_items
  add column if not exists batch_id bigint references public.inventory_batches (id) on delete set null;

create index if not exists mobile_stock_request_items_batch_idx
  on public.mobile_stock_request_items (batch_id);

comment on column public.mobile_stock_request_items.batch_id is
  'Konkrétní šarže zvolená při nakládce; její batch_id se zachová ve skladových pohybech sklad → vozidlo → automat.';

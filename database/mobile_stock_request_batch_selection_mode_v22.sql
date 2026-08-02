begin;

alter table public.mobile_stock_request_items
  add column if not exists batch_selection_mode text not null default 'auto';

alter table public.mobile_stock_request_items
  drop constraint if exists mobile_stock_request_items_batch_selection_mode_check;

alter table public.mobile_stock_request_items
  add constraint mobile_stock_request_items_batch_selection_mode_check
  check (batch_selection_mode in ('auto', 'manual'));

comment on column public.mobile_stock_request_items.batch_selection_mode is
  'auto = rozdělit množství FEFO přes více šarží; manual = začít od explicitně zvolené šarže a pokračovat FEFO.';

commit;

notify pgrst, 'reload schema';

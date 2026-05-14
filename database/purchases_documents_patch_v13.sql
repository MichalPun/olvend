alter table public.purchase_orders
  add column if not exists document_type text not null default 'invoice'
    check (document_type in ('invoice', 'delivery_note', 'cash_receipt', 'internal_receipt')),
  add column if not exists due_date date;

create index if not exists purchase_orders_document_type_idx
  on public.purchase_orders (document_type);

create index if not exists purchase_orders_due_date_idx
  on public.purchase_orders (due_date);

alter table public.purchase_recurring_orders
  add column if not exists valid_until date;

create index if not exists purchase_recurring_orders_valid_until_idx
  on public.purchase_recurring_orders (valid_until);

alter table public.purchase_suppliers
  add column if not exists company_id text,
  add column if not exists tax_id text,
  add column if not exists address text;

create index if not exists purchase_suppliers_company_id_idx
  on public.purchase_suppliers (company_id);
